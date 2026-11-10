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
	"errors"
	"io"
	"net"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"shinro-backend/internal/connectivity"
	"shinro-backend/internal/geo"
	"shinro-backend/internal/logger"
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

	// pumpsWG cuenta los pumps de módulo activos para poder esperar a que
	// terminen durante el graceful shutdown.
	pumpsWG sync.WaitGroup
}

func NewServer(registry *Registry, connMon *connectivity.Monitor) *Server {
	path := os.Getenv("SHINRO_SOCKET_PATH")
	if path == "" {
		uid := os.Geteuid()
		path = "/run/user/" + strconv.Itoa(uid) + "/shinro"
	}
	return &Server{
		path:     path,
		registry: registry,
		connMon:  connMon,
		clients:  make(map[*client]bool),
	}
}

// Start arranca el servidor y bloquea hasta que el contexto se cancele.
// Al cancelarse (SIGTERM/SIGINT), cierra todos los clientes activos y espera
// a que terminen los pumps antes de salir (graceful shutdown).
func (s *Server) Start(ctx context.Context) error {
	dir := "/run/user/" + strconv.Itoa(os.Geteuid())
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
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

	go s.acceptLoop(ctx)
	if s.connMon != nil {
		go s.connMon.Run(ctx)
		go s.watchConnectivity(ctx)
	}
	<-ctx.Done()
	logger.Info("señal de parada recibida, iniciando graceful shutdown")

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
	go func() {
		s.pumpsWG.Wait()
		close(done)
	}()

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

	subSys bool
	subWth bool
	intSys int // segundos
	intWth int
	city   string
	mode   geo.Mode
	lang   string

	// pump*Started marca si la goroutine del pump del módulo ya está viva.
	pumpSysStarted bool
	pumpWthStarted bool

	// Estado genérico por módulo para el registro.
	subs         map[string]bool
	modWakes     map[string]chan struct{}
	modStarted   map[string]bool
	modIntervals map[string]int

	// server permite a los pumps acceder al WaitGroup del servidor.
	server *Server
}

// write encola un mensaje sin bloquearse si el cliente ya se fue.
func (c *client) write(msg []byte) {
	select {
	case <-c.done:
		return
	default:
	}

	select {
	case c.send <- msg:
	case <-c.done:
	default:
		// Cliente lento o saturado: descartar antes que bloquear el pump.
	}
}

// close cierra el cliente una sola vez. No se cierra el canal `send`:
// los pumps pueden seguir intentando escribir y verán `done` cerrado.
func (c *client) close() {
	c.closeOnce.Do(func() {
		close(c.done)
		_ = c.conn.Close()
	})
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
				logger.Warn("error aceptando conexión", "error", err)
				continue
			}
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
		go c.writeLoop()
		go s.readLoop(c)
	}
}

func (c *client) writeLoop() {
	for {
		select {
		case <-c.done:
			return
		case msg := <-c.send:
			if _, err := c.conn.Write(msg); err != nil {
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
		logger.Info("cliente desconectado", "addr", c.conn.RemoteAddr())
	}()

	for {
		line, err := c.reader.ReadString('\n')
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
		if err := json.Unmarshal([]byte(line), &raw); err != nil {
			logger.Warn("no se pudo parsear JSON", "error", err, "linea", line)
			continue
		}

		var msgType string
		_ = json.Unmarshal(raw["type"], &msgType)

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

// handleHello procesa el handshake, responde y arranca el empuje periódico
// de cada módulo suscrito.
func (s *Server) handleHello(c *client, raw map[string]json.RawMessage) {
	for _, name := range s.registry.Names() {
		m := s.registry.Get(name)
		if m == nil {
			continue
		}
		m.HandleHello(c, raw)
	}

	c.mu.Lock()
	mode := c.mode
	city := c.city
	c.mu.Unlock()

	resp, _ := json.Marshal(map[string]interface{}{
		"type": "hello",
		"ok":   true,
		"mode": mode,
		"city": city,
	})
	c.write(writeBuf(resp))
	logger.Debug("handshake respondido", "client", c.conn.RemoteAddr(), "mode", mode, "city", city)
}

// handleGet responde con un snapshot inmediato del módulo pedido.
func (s *Server) handleGet(c *client, raw map[string]json.RawMessage) {
	var module string
	if modRaw, ok := raw["module"]; ok {
		_ = json.Unmarshal(modRaw, &module)
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
	m.HandleGet(c, raw)
}

// watchConnectivity observa los cambios de conectividad y, al recuperar la
// red, fuerza un refresco inmediato del clima en todos los clientes
// suscritos sin esperar al próximo tick programado.
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
				logger.Info("conectividad recuperada, refrescando clima de clientes")
				s.wakeWeatherClients()
			case connectivity.StateOffline:
				logger.Info("sin conexión a Internet, se servirán datos en caché si existen")
			}
		}
	}
}

// wakeWeatherClients despierta el pump de weather de cada cliente suscrito
// para que obtenga un parte nuevo inmediatamente.
func (s *Server) wakeWeatherClients() {
	s.mu.Lock()
	clients := make([]*client, 0, len(s.clients))
	for c := range s.clients {
		if c.isSubscribed("weather") {
			clients = append(clients, c)
		}
	}
	s.mu.Unlock()

	for _, c := range clients {
		c.signalMod("weather")
	}
}

func (s *Server) sendError(c *client, message string) {
	msg, _ := json.Marshal(map[string]string{
		"type":    "error",
		"message": message,
	})
	c.write(writeBuf(msg))
	logger.Warn("error enviado al cliente", "client", c.conn.RemoteAddr(), "message", message)
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
func pumpModule(m Module, c *client, done <-chan struct{}) {
	if c.server != nil {
		c.server.pumpsWG.Add(1)
		defer c.server.pumpsWG.Done()
	}

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
			// Volver al inicio para releer el intervalo y enviar de inmediato.
			continue
		case <-timer.C:
			if err := m.SendUpdate(c); err != nil {
				logger.Warn("módulo: error enviando update", "module", m.Name(), "client", c.conn.RemoteAddr(), "error", err)
			}
		}
	}
}
