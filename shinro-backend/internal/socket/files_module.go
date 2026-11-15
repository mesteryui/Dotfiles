// Package socket expone el módulo files sobre el socket Unix de shinro.
package socket

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"time"

	"shinro-backend/internal/files"
	"shinro-backend/internal/logger"
	"shinro-backend/internal/safe"
)

// filesOpKey identifica la operación asíncrona de búsqueda de archivos dentro
// del cliente. Es la clave con la que se registra su cancelación: el socket
// solo sabe "hay una operación en vuelo" y que debe abortarla al cerrarse la
// conexión, pero no qué es ni de qué módulo viene.
const filesOpKey = "files"

// filesRefreshMinInterval es el intervalo mínimo entre refrescos
// automáticos del mismo cliente.
//
// El sistema de archivos cambia constantemente (navegador, compilaciones,
// sincronizaciones). Sin este tope, cada cambio provocaría un recorrido
// completo del disco; con él, la lista del cliente se actualiza como mucho
// cada few segundos, que es de sobra para el ojo humano.
const filesRefreshMinInterval = 3 * time.Second

// FilesModule busca archivos en el sistema de archivos.
type FilesModule struct {
	provider *files.Provider

	// mu protege queries.
	//
	// queries recuerda la última búsqueda que hizo cada cliente, para poder
	// reejecutarla cuando cambie el sistema de archivos y empujarle el
	// resultado actualizado sin que tenga que pedirlo.
	mu      sync.Mutex
	queries map[*client]*filesQuery
}

// filesQuery es el estado de búsqueda de un cliente.
type filesQuery struct {
	query string
	limit int
	// lastPush es el momento del último refresco enviado al cliente.
	lastPush time.Time
	// pending indica que ya hay un refresco programado (para no programar
	// varios).
	pending bool
}

// NewFilesModule crea un módulo de archivos con el proveedor dado.
func NewFilesModule(provider *files.Provider) *FilesModule {
	module := &FilesModule{
		provider: provider,
		queries:  make(map[*client]*filesQuery),
	}
	// Cuando el sistema de archivos cambia, se reejecuta la última
	// búsqueda de cada cliente y se le empuja el resultado nuevo: la lista
	// se queda al día sola, sin que la UI tenga que preguntar.
	provider.SetOnChange(module.onFilesystemChange)
	return module
}

func (module *FilesModule) Name() string { return "files" }

func (module *FilesModule) HandleHello(cliente *client, raw map[string]json.RawMessage) {
}

func (module *FilesModule) HandleGet(cliente *client, raw map[string]json.RawMessage) error {
	var action string
	if a, ok := raw["action"]; ok {
		_ = json.Unmarshal(a, &action)
	}

	switch action {
	case "search":
		module.handleSearch(cliente, raw)
		return nil
	default:
		sendErrorToClient(cliente, module.Name(), "acción desconocida: se espera search")
		return fmt.Errorf("acción desconocida: se espera search")
	}
}

// handleSearch lanza la búsqueda en una goroutine para no bloquear el
// readLoop del socket. El cliente puede seguir enviando nuevas peticiones
// mientras la anterior está en vuelo; el QML descarta respuestas obsoletas
// comparando la query de la respuesta con la última enviada.
//
// Cada búsqueda cancela la anterior del mismo cliente: teclear rápido no
// deja búsquedas recorriendo el disco a la vez (ni goroutines acumuladas).
func (module *FilesModule) handleSearch(cliente *client, raw map[string]json.RawMessage) {
	var query string
	if queryRaw, ok := raw["query"]; ok {
		_ = json.Unmarshal(queryRaw, &query)
	}
	var limit int
	if limitRaw, ok := raw["limit"]; ok {
		_ = json.Unmarshal(limitRaw, &limit)
	}
	if limit <= 0 {
		limit = 20
	}

	// Recordar la búsqueda para poder refrescarla sola si el sistema de
	// archivos cambia.
	module.rememberQuery(cliente, query, limit)

	module.runSearch(cliente, query, limit)
}

// rememberQuery guarda la última búsqueda del cliente.
func (module *FilesModule) rememberQuery(cliente *client, query string, limit int) {
	module.mu.Lock()
	defer module.mu.Unlock()

	// Poda: los clientes que se fueron no vuelven a buscar, pero su estado
	// se quedaría en el mapa para siempre.
	for c := range module.queries {
		if c == cliente {
			continue
		}
		select {
		case <-c.done:
			delete(module.queries, c)
		default:
		}
	}

	state, ok := module.queries[cliente]
	if !ok {
		state = &filesQuery{}
		module.queries[cliente] = state
	}
	state.query = query
	state.limit = limit
}

// ClientGone olvida la última búsqueda del cliente que se ha ido.
//
// Sin esto, el mapa de consultas guardaría una entrada por cada cliente que
// hubiera buscado alguna vez, para siempre: una fuga lenta pero real.
func (module *FilesModule) ClientGone(cliente *client) {
	module.mu.Lock()
	delete(module.queries, cliente)
	module.mu.Unlock()
}

// runSearch ejecuta la búsqueda y empuja el resultado al cliente.
func (module *FilesModule) runSearch(cliente *client, query string, limit int) {
	// Cancelar la búsqueda anterior del cliente (si la hay): una query nueva
	// aborta la anterior para no dejar dos recorridos del disco en curso.
	cliente.cancelInFlight(filesOpKey)

	ctx, cancel := context.WithCancel(context.Background())
	cliente.setCancelInFlight(filesOpKey, cancel)

	// Ejecutar en goroutine: no bloquear el readLoop mientras filepath.WalkDir
	// recorre el disco. El cliente puede seguir enviando peticiones.
	safe.Go("socket.files.search", func() {
		defer cancel()

		inicio := time.Now()
		results, err := module.provider.SearchContext(ctx, query, "", limit)
		if err != nil && errors.Is(err, context.Canceled) {
			// Búsqueda cancelada: el resultado ya no interesa, no es un error
			// (el cliente pidió otra búsqueda o se fue).
			logger.Debug("files search cancelado", "client", cliente.conn.RemoteAddr(), "query", query)
			return
		}
		// Anotar el resultado para el informe de salud: el módulo files no
		// tiene pump, así que sin esto no se sabría que está trabajando.
		if cliente.server != nil {
			cliente.server.recordModuleResult(module.Name(), err, time.Since(inicio))
		}
		if err != nil {
			sendErrorToClient(cliente, module.Name(), "error buscando archivos: "+err.Error())
			return
		}

		msg, _ := json.Marshal(map[string]interface{}{
			"type":   "update",
			"module": "files",
			"data": map[string]any{
				"query":   query,
				"results": results,
			},
		})
		cliente.write(writeBuf(msg))
		logger.Debug("files search enviado", "client", cliente.conn.RemoteAddr(), "query", query, "results", len(results))
	})
}

// onFilesystemChange reejecuta la última búsqueda de cada cliente y le
// empuja el resultado actualizado.
//
// El backend se entera de los cambios por evento (inotify), no por polling:
// cuando cambia el sistema de archivos, la lista de la UI se refresca sola.
func (module *FilesModule) onFilesystemChange() {
	now := time.Now()

	type job struct {
		cliente *client
		query   string
		limit   int
	}

	module.mu.Lock()
	var jobs []job
	for cliente, state := range module.queries {
		// Poda: si el cliente se fue, su estado ya no sirve de nada.
		select {
		case <-cliente.done:
			delete(module.queries, cliente)
			continue
		default:
		}

		// No repetir búsqueda si el cliente ya no pide nada.
		if state.query == "" && state.limit == 0 {
			continue
		}

		since := now.Sub(state.lastPush)
		if since < filesRefreshMinInterval {
			// Todavía es pronto: programar el refresco para cuando toque,
			// salvo que ya haya uno programado.
			if !state.pending {
				state.pending = true
				restante := filesRefreshMinInterval - since
				time.AfterFunc(restante, func() {
					module.refresh(cliente)
				})
			}
			continue
		}

		state.lastPush = now
		jobs = append(jobs, job{cliente: cliente, query: state.query, limit: state.limit})
	}
	module.mu.Unlock()

	for _, j := range jobs {
		module.runSearch(j.cliente, j.query, j.limit)
	}
}

// refresh reejecuta la búsqueda guardada de un cliente (usado por los
// refrescos programados).
func (module *FilesModule) refresh(cliente *client) {
	module.mu.Lock()
	state, ok := module.queries[cliente]
	if !ok {
		module.mu.Unlock()
		return
	}
	select {
	case <-cliente.done:
		delete(module.queries, cliente)
		module.mu.Unlock()
		return
	default:
	}
	state.pending = false
	state.lastPush = time.Now()
	query, limit := state.query, state.limit
	module.mu.Unlock()

	module.runSearch(cliente, query, limit)
}

// SendUpdate devuelve una lista vacía (no hay estado persistente).
func (module *FilesModule) SendUpdate(cliente *client) error {
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "files",
		"data":   map[string]any{"results": []*files.Result{}},
	})
	cliente.write(writeBuf(msg))
	return nil
}

// compilo-check de que implementa Module.
var _ Module = (*FilesModule)(nil)
