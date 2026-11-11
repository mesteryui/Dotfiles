// Package socket expone el módulo files sobre el socket Unix de shinro.
package socket

import (
	"encoding/json"

	"shinro-backend/internal/files"
	"shinro-backend/internal/logger"
)

// FilesModule busca archivos en el sistema de archivos.
type FilesModule struct {
	provider *files.Provider
}

// NewFilesModule crea un módulo de archivos con el proveedor dado.
func NewFilesModule(provider *files.Provider) *FilesModule {
	return &FilesModule{provider: provider}
}

func (module *FilesModule) Name() string { return "files" }

func (module *FilesModule) HandleHello(cliente *client, raw map[string]json.RawMessage) (bool, <-chan struct{}) {
	return false, nil
}

func (module *FilesModule) HandleGet(cliente *client, raw map[string]json.RawMessage) {
	var action string
	if a, ok := raw["action"]; ok {
		_ = json.Unmarshal(a, &action)
	}

	switch action {
	case "search":
		module.handleSearch(cliente, raw)
	default:
		sendErrorToClient(cliente, module.Name(), "acción desconocida: se espera search")
	}
}

// handleSearch lanza la búsqueda en una goroutine para no bloquear el
// readLoop del socket. El cliente puede seguir enviando nuevas peticiones
// mientras la anterior está en vuelo; el QML descarta respuestas obsoletas
// comparando la query de la respuesta con la última enviada.
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

	// Ejecutar en goroutine: no bloquear el readLoop mientras filepath.WalkDir
	// recorre el disco. El cliente puede seguir enviando peticiones.
	go func() {
		results, err := module.provider.Search(query, "", limit)
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
	}()
}

// Pump es un no-op para files: no hay actualizaciones periódicas.
func (module *FilesModule) Pump(cliente *client, wake <-chan struct{}, done <-chan struct{}) {
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
