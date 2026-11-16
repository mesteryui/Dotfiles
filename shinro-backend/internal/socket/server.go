// Package socket implementa el servidor Unix socket llamado "shinro".
// Recibe mensajes JSON de Quickshell y empuja actualizaciones periódicas
// de los módulos registrados a los clientes suscritos.
//
// El servidor mantiene la conexión abierta indefinidamente: solo el cliente
// decide cuándo cerrarla. Cada cliente es independiente, de modo que la
// desconexión de uno nunca afecta a los demás.
//
// Los módulos (system, weather, ping, ...) se registran en un Registry e
// implementan la interfaz Module. Añadir un módulo nuevo solo requiere
// implementar Module y registrarlo en cmd/shinro-backend/main.go; no hay
// que tocar este archivo.
package socket

import (
	"bufio"
	"context"
	"encoding/json"
	encodingjsonv2 "encoding/json/v2"
	"errors"
	"io"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"shinro-backend/internal/connectivity"
	"shinro-backend/internal/geo"
	"shinro-backend/internal/logger"
	"shinro-backend/internal/safe"
	"shinro-backend/internal/system"
	"shinro-backend/internal/weather"
)

// Server escucha en un socket Unix y distribuye datos por módulo.
type Server struct {
	path     string
	registry *Registry
	connMon  *connectivity.Monitor
	listener net.Listener
	clients  map[*client]bool
	mu       sync.Mutex

	// stopping se activa al empezar el apagado: a partir de ese momento no
	// se arrancan pumps nuevos, para no llamar a pumpsWG.Add() mientras el
	// graceful shutdown ya está esperando en pumpsWG.Wait().
	stopping atomic.Bool

	// pumpsWG cuenta los pumps de módulo activos para poder esperar a que
	// terminen durante el graceful shutdown.
	pumpsWG sync.WaitGroup

	// startedAt es el instante de arranque del daemon (para el uptime).
	startedAt time.Time

	// history guarda las últimas mediciones del daemon. La comparación
	// contra el arranque no sirve (el daemon arranca módulos a medida que
	// llegan clientes), pero la tendencia sí: delata una fuga.
	history *healthHistory

	// healthLogMu y lastHealthLog controlan que el aviso de fuga en el log
	// no se repita cada 30 segundos.
	healthLogMu   sync.Mutex
	lastHealthLog time.Time

	// statsMu protege stats: el registro de salud por módulo (envíos,
	// errores y duración). Lo rellenan los pumps, las broadcasts y las
	// peticiones puntuales.
	statsMu sync.Mutex
	stats   map[string]*moduleStat
}

// healthProvider es implementado por el módulo que expone el informe de
// salud (ping). El servidor le inyecta la función que construye el informe,
// sin acoplar el servidor al tipo concreto del módulo.
type healthProvider interface {
	SetHealthProvider(fn func(c *client) Health)
}

// socketPathDefault devuelve la ruta por defecto del socket Unix.
//
// El orden es el mismo que usan los clientes (QML y CLI):
//
//	$SHINRO_SOCKET_PATH  →  $XDG_RUNTIME_DIR/shinro  →  /run/user/$UID/shinro
//
// Todas las rutas son opcionales: con el entorno tal cual (XDG_RUNTIME_DIR
// definido por systemd --user) el resultado es /run/user/$UID/shinro.
func socketPathDefault() string {
	if p := os.Getenv("SHINRO_SOCKET_PATH"); p != "" {
		return p
	}
	if rt := os.Getenv("XDG_RUNTIME_DIR"); rt != "" {
		return filepath.Join(rt, "shinro")
	}
	return "/run/user/" + strconv.Itoa(os.Geteuid()) + "/shinro"
}

func NewServer(registry *Registry, connMon *connectivity.Monitor) *Server {
	s := &Server{
		path:      socketPathDefault(),
		registry:  registry,
		connMon:   connMon,
		clients:   make(map[*client]bool),
		startedAt: time.Now(),
		history:   newHealthHistory(),
		stats:     make(map[string]*moduleStat),
	}
	// Inyectar el informe de salud al módulo que lo expone (ping), si lo
	// hay. Así el módulo ping no necesita conocer al servidor.
	if hp, ok := registry.Get("ping").(healthProvider); ok {
		hp.SetHealthProvider(s.snapshotHealth)
	}
	return s
}

// Start arranca el servidor y bloquea hasta que el contexto se cancele.
// Al cancelarse (SIGTERM/SIGINT), cierra todos los clientes activos y espera
// a que terminen los pumps antes de salir (graceful shutdown).
func (s *Server) Start(ctx context.Context) error {
	// Crear el directorio del socket (puede ser otro si se redefinió con
	// SHINRO_SOCKET_PATH).
	if dir := filepath.Dir(s.path); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0700); err != nil {
			return err
		}
	}

	_ = os.Remove(s.path)
	ln, err := net.Listen("unix", s.path)
	if err != nil {
		return err
	}
	s.listener = ln
	if err := os.Chmod(s.path, 0660); err != nil {
		logger.Warn("no se pudo establecer permisos del socket", "path", s.path, "error", err)
	}

	logger.Info("shinro socket escuchando", "path", s.path)

	// Muestrear el estado del daemon periódicamente: el historial permite
	// distinguir una fuga de un simple transitorio de arranque.
	s.startHealthSampler(ctx)

	safe.Go("socket.accept", func() { s.acceptLoop(ctx) })
	if s.connMon != nil {
		safe.Go("connectivity.run", func() { s.connMon.Run(ctx) })
		safe.Go("socket.connectivity", func() { s.watchConnectivity(ctx) })
	}
	<-ctx.Done()
	logger.Info("señal de parada recibida, iniciando graceful shutdown")

	// Marcar el servidor como parado: no se arrancan pumps nuevos (ni se
	// llama a pumpsWG.Add() mientras Wait() está en curso).
	s.stopping.Store(true)

	// Cerrar todos los clientes activos: esto cierra done y hace que los
	// pumps terminen.
	s.mu.Lock()
	clients := make([]*client, 0, len(s.clients))
	for c := range s.clients {
		clients = append(clients, c)
	}
	s.mu.Unlock()

	for _, c := range clients {
		c.close()
	}

	// Esperar a que terminen los pumps (máximo 5 segundos).
	done := make(chan struct{})
	safe.Go("socket.shutdown", func() {
		s.pumpsWG.Wait()
		close(done)
	})

	select {
	case <-done:
		logger.Info("todos los pumps terminaron")
	case <-time.After(5 * time.Second):
		logger.Warn("timeout esperando a que terminen los pumps")
	}

	if s.connMon != nil {
		if err := s.connMon.Close(); err != nil {
			logger.Warn("error cerrando monitor de conectividad", "error", err)
		}
	}

	_ = s.listener.Close()
	_ = os.Remove(s.path)
	logger.Info("shinro socket detenido")
	return nil
}

type client struct {
	conn   net.Conn
	reader *bufio.Reader
	send   chan []byte
	done   chan struct{}

	closeOnce sync.Once
	mu        sync.Mutex

	city string
	mode geo.Mode
	lang string

	// pump*Started marca si la goroutine del pump del módulo ya está viva.
	pumpSysStarted bool
	pumpWthStarted bool

	// Estado genérico por módulo para el registro.
	subs         map[string]bool
	modWakes     map[string]chan struct{}
	modIntervals map[string]int

	// cancelMu protege cancels.
	//
	// cancels permite a un módulo registrar una operación asíncrona en
	// vuelo ligada a este cliente (por ejemplo, una búsqueda de ficheros)
	// para poder abortarla. El servidor NO sabe QUÉ se cancela ni por qué:
	// solo ofrece el mecanismo y se encarga de abortar todo al cerrarse la
	// conexión, porque "el cliente se fue" es un evento del ciclo de vida de
	// la conexión y por eso vive en el cliente y no en cada módulo.
	//
	// La clave permite que varios módulos operen en paralelo sin pisarse.
	cancelMu sync.Mutex
	cancels  map[string]context.CancelFunc

	// server permite a los pumps acceder al WaitGroup del servidor.
	server *Server
}

// write encola un mensaje sin bloquearse si el cliente ya se fue.
//
// Devuelve false si el mensaje se ha descartado (cliente ido o saturado), para
// que quien lo envíe pueda reintentar o al menos dejar constancia en el log.
func (c *client) write(msg []byte) bool {
	select {
	case <-c.done:
		putBuf(msg)
		return false
	default:
	}

	select {
	case c.send <- msg:
		return true
	case <-c.done:
		putBuf(msg)
		return false
	default:
		// Cliente lento o saturado: descartar antes que bloquear el pump.
		// El buffer vuelve al pool para no desperdiciarlo.
		putBuf(msg)
		return false
	}
}

// close cierra el cliente una sola vez. No se cierra el canal `send`:
// los pumps pueden seguir intentando escribir y verán `done` cerrado.
func (c *client) close() {
	c.closeOnce.Do(func() {
		close(c.done)
		// Abortar las operaciones en vuelo: si no, sus goroutines seguirían
		// trabajando (recorriendo el disco, por ejemplo) sin poder
		// entregar el resultado a nadie.
		c.cancelAllInFlight()
		if c.conn != nil {
			_ = c.conn.Close()
		}
	})
}

// cancelInFlight aborta la operación en vuelo identificada por key (si la hay)
// y la descarga. Lo usa un módulo para cancelar la petición anterior de ese
// cliente cuando llega una nueva.
func (c *client) cancelInFlight(key string) {
	c.cancelMu.Lock()
	cancel := c.cancels[key]
	delete(c.cancels, key)
	c.cancelMu.Unlock()
	if cancel != nil {
		cancel()
	}
}

// setCancelInFlight registra la cancelación de la operación en vuelo con esa
// clave. Si ya había una, se aborta: solo puede haber una operación en vuelo
// por clave y cliente.
func (c *client) setCancelInFlight(key string, cancel context.CancelFunc) {
	c.cancelMu.Lock()
	if c.cancels == nil {
		c.cancels = make(map[string]context.CancelFunc)
	}
	previous := c.cancels[key]
	c.cancels[key] = cancel
	c.cancelMu.Unlock()
	if previous != nil {
		previous()
	}
}

// cancelAllInFlight aborta todas las operaciones en vuelo del cliente.
func (c *client) cancelAllInFlight() {
	c.cancelMu.Lock()
	cancels := make([]context.CancelFunc, 0, len(c.cancels))
	for key, cancel := range c.cancels {
		cancels = append(cancels, cancel)
		delete(c.cancels, key)
	}
	c.cancelMu.Unlock()
	for _, cancel := range cancels {
		cancel()
	}
}

// startPump arranca el pump periódico de un módulo para este cliente.
func (c *client) startPump(m Module) {
	if c.server != nil {
		c.server.startPump(m, c)
		return
	}
	safe.Go("socket.pump."+m.Name(), func() { pumpModule(m, c, c.done) })
}

// acceptLoop acepta nuevas conexiones Unix.
func (s *Server) acceptLoop(ctx context.Context) {
	for {
		conn, err := s.listener.Accept()
		if err != nil {
			select {
			case <-ctx.Done():
				return
			default:
			}
			// El listener puede fallar de forma transitoria (límite de
			// descriptores, socket cerrado...). Sin una pausa, el bucle
			// entraría en modo busy loop y quemaría CPU de forma continua
			// durante los días que el daemon esté vivo.
			logger.Warn("error aceptando conexión", "error", err)
			if !sleepCtx(ctx, 100*time.Millisecond) {
				return
			}
			continue
		}

		c := &client{
			conn:   conn,
			reader: bufio.NewReader(conn),
			send:   make(chan []byte, 128),
			done:   make(chan struct{}),
			server: s,
		}

		s.mu.Lock()
		s.clients[c] = true
		s.mu.Unlock()

		logger.Info("cliente conectado", "addr", conn.RemoteAddr())
		safe.Go("socket.write", func() { c.writeLoop() })
		safe.Go("socket.read", func() { s.readLoop(c) })
	}
}

func (c *client) writeLoop() {
	for {
		select {
		case <-c.done:
			return
		case msg := <-c.send:
			_, err := c.conn.Write(msg)
			// Devolver el buffer al pool: en un daemon de larga vida, el
			// churn de mensajes es constante y esto evita malloc por envío.
			putBuf(msg)
			if err != nil {
				// El cliente se fue: cerrar solo este cliente.
				logger.Warn("error de escritura al cliente", "addr", c.conn.RemoteAddr(), "error", err)
				c.close()
				return
			}
		}
	}
}

func (s *Server) readLoop(c *client) {
	defer func() {
		c.close()
		s.mu.Lock()
		delete(s.clients, c)
		s.mu.Unlock()
		// Avisar a los módulos de que este cliente se ha ido, para que
		// suelten el estado que guardaban de él.
		s.notifyClientGone(c)
		logger.Info("cliente desconectado", "addr", c.conn.RemoteAddr())
	}()

	for {
		line, err := readClientLine(c.reader)
		if err != nil {
			if errors.Is(err, io.EOF) {
				logger.Debug("cliente cerró (EOF)", "addr", c.conn.RemoteAddr())
				return
			}
			logger.Warn("lectura terminada", "addr", c.conn.RemoteAddr(), "error", err)
			return
		}

		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		var raw map[string]json.RawMessage
		if err := encodingjsonv2.Unmarshal([]byte(line), &raw); err != nil {
			logger.Warn("no se pudo parsear JSON", "error", err, "linea", line)
			continue
		}

		var msgType string
		_ = encodingjsonv2.Unmarshal(raw["type"], &msgType)

		switch msgType {
		case "hello":
			s.handleHello(c, raw)
		case "get":
			s.handleGet(c, raw)
		default:
			logger.Warn("mensaje desconocido", "type", msgType)
		}
	}
}

// maxClientLineBytes es el tamaño máximo de una línea JSON recibida.
//
// Sin tope, un cliente (o un bug) podría mandar una línea enorme y hacer
// crecer la memoria del daemon sin límite: el daemon es un proceso de larga
// vida y no puede depender de que todos sus clientes se porten bien.
const maxClientLineBytes = 1 << 20 // 1 MiB

// errLineTooLong indica que la línea recibida supera el máximo permitido.
var errLineTooLong = errors.New("línea demasiado larga")

// readClientLine lee una línea terminada en '\n' con un tope de tamaño.
//
// Si la línea es demasiado larga, se consume el resto hasta el fin de línea
// (para no desincronizar el stream) y se devuelve errLineTooLong.
func readClientLine(r *bufio.Reader) (string, error) {
	var sb strings.Builder
	for {
		chunk, err := r.ReadSlice('\n')
		if sb.Len()+len(chunk) > maxClientLineBytes {
			// Drenar el resto de la línea antes de devolver el error.
			for err == bufio.ErrBufferFull {
				_, err = r.ReadSlice('\n')
			}
			return "", errLineTooLong
		}
		sb.Write(chunk)
		if err == bufio.ErrBufferFull {
			// El buffer interno se llenó: sigue leyendo, la línea aún no
			// ha terminado.
			continue
		}
		if err != nil {
			return "", err
		}
		return sb.String(), nil
	}
}

// notifyClientGone avisa a los módulos de que un cliente se ha ido.
//
// Los módulos que guardan estado por cliente (como files, que recuerda la
// última búsqueda de cada uno) lo sueltan así: si no, ese estado se
// acumularía para siempre.
func (s *Server) notifyClientGone(c *client) {
	for _, name := range s.registry.Names() {
		m := s.registry.Get(name)
		if m == nil {
			continue
		}
		if cg, ok := m.(ClientGone); ok {
			cg.ClientGone(c)
		}
	}
}

// handleHello procesa el handshake, responde y arranca el empuje periódico
// de cada módulo suscrito.
func (s *Server) handleHello(c *client, raw map[string]json.RawMessage) {
	// Extraer ubicación si viene en raw para responder el handshake
	if locRaw, ok := raw["location"]; ok {
		var loc struct {
			Mode geo.Mode `json:"mode"`
			City string   `json:"city"`
		}
		if err := encodingjsonv2.Unmarshal(locRaw, &loc); err == nil {
			c.mu.Lock()
			if loc.Mode != "" {
				c.mode = loc.Mode
			}
			if loc.City != "" {
				c.city = loc.City
			}
			c.mu.Unlock()
		}
	}

	c.mu.Lock()
	mode := c.mode
	city := c.city
	c.mu.Unlock()

	resp, _ := encodingjsonv2.Marshal(map[string]interface{}{
		"type": "hello",
		"ok":   true,
		"mode": mode,
		"city": city,
	})
	// Responder primero para garantizar que hello sea el primer mensaje en la cola
	c.write(writeBuf(resp))
	logger.Debug("handshake respondido", "client", c.conn.RemoteAddr(), "mode", mode, "city", city)

	// Procesar las suscripciones de cada módulo
	for _, name := range s.registry.Names() {
		m := s.registry.Get(name)
		if m == nil {
			continue
		}
		m.HandleHello(c, raw)
	}
}

// handleGet responde con un snapshot inmediato del módulo pedido.
func (s *Server) handleGet(c *client, raw map[string]json.RawMessage) {
	var module string
	if modRaw, ok := raw["module"]; ok {
		_ = encodingjsonv2.Unmarshal(modRaw, &module)
	}
	logger.Debug("get request", "client", c.conn.RemoteAddr(), "module", module)

	if module == "" {
		s.sendError(c, "módulo no especificado")
		return
	}

	m := s.registry.Get(module)
	if m == nil {
		s.sendError(c, "módulo desconocido: "+module)
		return
	}

	inicio := time.Now()
	err := m.HandleGet(c, raw)
	s.recordModuleResult(module, err, time.Since(inicio))
}

// watchConnectivity observa los cambios de conectividad y, al recuperar la
// red, fuerza un refresco inmediato de los módulos online (clima, etc.) en todos
// los clientes suscritos sin esperar al próximo tick programado.
func (s *Server) watchConnectivity(ctx context.Context) {
	if s.connMon == nil {
		return
	}
	ch := s.connMon.Subscribe()
	defer s.connMon.Unsubscribe(ch)
	for {
		select {
		case <-ctx.Done():
			return
		case state := <-ch:
			switch state {
			case connectivity.StateOnline:
				logger.Info("conectividad recuperada, refrescando módulos online de clientes")
				// Invalidar ANTES de despertar los pumps: si no, el
				// módulo podría servir lo cacheado (que puede tener horas)
				// en vez de pedir datos frescos.
				s.invalidateModuleCaches()
				s.WakeOnlineClients()
			case connectivity.StateOffline:
				logger.Info("sin conexión a Internet, se servirán datos en caché si existen")
			}
		}
	}
}

// invalidateModuleCaches pide a los módulos que descarten lo cacheado.
//
// Se usa al recuperar la conectividad: durante un corte, los datos cacheados
// pueden quedarse muy viejos.
func (s *Server) invalidateModuleCaches() {
	for _, name := range s.registry.Names() {
		m := s.registry.Get(name)
		if m == nil {
			continue
		}
		if inv, ok := m.(ModuleInvalidator); ok {
			inv.InvalidateCaches()
		}
	}
}

// WakeOnlineClients despierta los pumps de todos los módulos dependientes de Internet
// (como weather) para que obtengan datos frescos de inmediato.
func (s *Server) WakeOnlineClients() {
	s.mu.Lock()
	clients := make([]*client, 0, len(s.clients))
	for c := range s.clients {
		clients = append(clients, c)
	}
	s.mu.Unlock()

	for _, c := range clients {
		for _, name := range s.registry.Names() {
			m := s.registry.Get(name)
			if m == nil {
				continue
			}
			if IsOnlineModule(m) && c.isSubscribed(name) {
				c.signalMod(name)
			}
		}
	}
}

// WakeClipboardClients empuja el historial actualizado a todos los clientes
// suscritos al portapapeles. El módulo clipboard no usa pump periódico (sus
// cambios llegan por eventos a través de SetBroadcast), así que aquí se envía
// el listado directamente en lugar de solo despertar el pump.
//
// El listado es una instantánea: si se pierde por saturación, el cliente se
// queda con un historial obsoleto hasta el siguiente cambio. Por eso se
// reintenta unas pocas veces antes de renunciar y, si aun así falla, se deja
// constancia en el log en lugar de perderlo en silencio.
func (s *Server) WakeClipboardClients() {
	s.mu.Lock()
	clients := make([]*client, 0, len(s.clients))
	for c := range s.clients {
		if c.isSubscribed("clipboard") {
			clients = append(clients, c)
		}
	}
	s.mu.Unlock()

	m := s.registry.Get("clipboard")
	if m == nil {
		return
	}
	for _, c := range clients {
		if err := s.sendClipboardUpdate(c, m); err != nil {
			logger.Warn("clipboard: error enviando update", "client", c.conn.RemoteAddr(), "error", err)
		}
	}
}

// sendClipboardUpdate envía el listado del portapapeles a un cliente,
// reintentando si el buffer del cliente está saturado.
func (s *Server) sendClipboardUpdate(c *client, m Module) error {
	const intentos = 5
	var err error
	for i := 0; i < intentos; i++ {
		inicio := time.Now()
		err = m.SendUpdate(c)
		s.recordModuleResult(m.Name(), err, time.Since(inicio))
		if err == nil {
			return nil
		}
		// El cliente está saturado: breve pausa y reintento.
		time.Sleep(10 * time.Millisecond)
	}
	return err
}

func (s *Server) sendError(c *client, message string) {
	sendErrorToClient(c, "server", message)
}

// NewDefaultRegistry crea y registra los módulos por defecto (system, weather, ping).
func NewDefaultRegistry(sys *system.Provider, wth *weather.Provider) *Registry {
	r := NewRegistry()
	r.Register(&systemModule{sysProvider: sys})
	r.Register(&weatherModule{wthProvider: wth})
	r.Register(&pingModule{})
	return r
}

// pumpModule ejecuta el bucle periódico de un módulo para un cliente.
// Se llama desde los módulos al arrancar un pump.
//
// Cada envío va protegido: un fallo puntual (por ejemplo, el proveedor de
// clima devolviendo basura) no debe matar el pump ni el daemon, solo
// reportarse al cliente como error.
func pumpModule(m Module, c *client, done <-chan struct{}) {
	name := m.Name()

	send := func(reason string) {
		inicio := time.Now()
		err := safe.Do("socket.pump."+name, func() error { return m.SendUpdate(c) })
		// Anotar el resultado para el informe de salud del módulo ping.
		if c.server != nil {
			c.server.recordModuleResult(name, err, time.Since(inicio))
		}
		if err != nil {
			logger.Warn("módulo: error enviando update",
				"module", name,
				"client", c.conn.RemoteAddr(),
				"razon", reason,
				"error", err,
			)
		}
	}

	// Envío inicial inmediato al comenzar la suscripción.
	// Si hay internet (o datos locales/caché), se entrega de inmediato al cliente.
	send("inicial")

	for {
		interval := c.modInterval(m.Name())
		if interval <= 0 {
			return
		}

		wake := c.modWake(m.Name())
		timer := time.NewTimer(time.Duration(interval) * time.Second)
		select {
		case <-done:
			timer.Stop()
			return
		case <-wake:
			timer.Stop()
			// Refresco forzado al recibir señal de wake (por ej. recuperación de internet o cambio de configuración)
			send("wake")
		case <-timer.C:
			send("tick")
		}
	}
}

// startPump arranca el pump periódico de un módulo para un cliente.
//
// El WaitGroup se incrementa ANTES de lanzar la goroutine: si se hiciera
// dentro, el graceful shutdown podría empezar a esperar antes de que el
// pump se registrara y terminar sin esperarlo (carrera entre Add y Wait).
func (s *Server) startPump(m Module, c *client) {
	// Durante el apagado no se arrancan pumps nuevos: pumpsWG.Wait() puede
	// estar en curso y llamar a Add() en ese momento es un uso incorrecto
	// del WaitGroup.
	if s.stopping.Load() {
		return
	}

	s.pumpsWG.Add(1)
	safe.Go("socket.pump."+m.Name(), func() {
		defer s.pumpsWG.Done()
		pumpModule(m, c, c.done)
	})
}

// sleepCtx duerme d o hasta que se cancele el contexto.
// Devuelve false si el contexto se canceló.
func sleepCtx(ctx context.Context, d time.Duration) bool {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return false
	case <-t.C:
		return true
	}
}
