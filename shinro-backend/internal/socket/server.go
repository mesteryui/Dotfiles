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
	json "encoding/json"
	encodingjsonv2 "encoding/json/v2"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"shinro-backend/internal/connectivity"
	"shinro-backend/internal/geo"
	"shinro-backend/internal/ipc"
	"shinro-backend/internal/logger"
	"shinro-backend/internal/safe"
	"shinro-backend/internal/system"
	"shinro-backend/internal/weather"
)

// ErrAlreadyRunning es el error que se devuelve cuando el daemon ya está
// escuchando en el socket Unix. Se usa para distinguir el caso de reinicio
// con systemd de otros fallos inicializadores.
var ErrAlreadyRunning = errors.New("ya hay un shinro-backend escuchando")

var jsonv2Options encodingjsonv2.Options = encodingjsonv2.RejectUnknownMembers(true)

// Server escucha en un socket Unix y distribuye datos por módulo.
type Server struct {
	path string
	// pathErr guarda el fallo al resolver la ruta del socket (por ejemplo,
	// si no hay XDG_RUNTIME_DIR). Start lo devuelve en vez de escuchar en
	// una ruta insegura.
	pathErr  error
	registry *Registry
	connMon  *connectivity.Monitor
	listener net.Listener
	clients  map[*client]bool
	mu       sync.Mutex

	// stopping se activa al empezar el apagado: a partir de ese momento no
	// se arrancan pumps nuevos, para no llamar a pumpsWG.Add() mientras el
	// graceful shutdown ya está esperando en pumpsWG.Wait().
	stopping atomic.Bool

	// shutdownMu serializa la transición de apagado con el arranque de pumps.
	// Garantiza que pumpsWG.Add() nunca ocurra concurrentemente con
	// pumpsWG.Wait().
	shutdownMu sync.Mutex

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

	// lockFile mantiene un flock exclusivo sobre el socket para evitar que
	// dos procesos de backend se arranquen simultáneamente y uno borre el
	// socket del otro (TOCTOU). Se adquiere en Start() y se libera al parar.
	lockFile *os.File
}

// healthProvider es implementado por el módulo que expone el informe de
// salud (ping). El servidor le inyecta la función que construye el informe,
// sin acoplar el servidor al tipo concreto del módulo.
type healthProvider interface {
	SetHealthProvider(fn func(c *client) Health)
}

// AcquireLock intenta adquirir un bloqueo exclusivo (flock) sobre socketPath+".lock".
// Si otro daemon ya está en ejecución, devuelve ErrAlreadyRunning de inmediato en 0 ms.
// El llamador debe mantener el archivo abierto durante la vida del daemon y cerrarlo al salir.
//
// El directorio se valida (propiedad y permisos) y el lockfile se abre con
// O_NOFOLLOW para que un enlace simbólico colocado por otro proceso no haga
// que bloqueemos o creemos un archivo ajeno.
func AcquireLock(socketPath string) (*os.File, error) {
	if socketPath == "" {
		return nil, errors.New("ruta de socket vacía")
	}
	if dir := filepath.Dir(socketPath); dir != "" && dir != "." {
		if err := ipc.EnsurePrivateDir(dir); err != nil {
			return nil, err
		}
	}
	f, err := os.OpenFile(socketPath+".lock",
		os.O_CREATE|os.O_RDWR|syscall.O_NOFOLLOW|syscall.O_CLOEXEC, 0o600)
	if err != nil {
		return nil, err
	}
	// Comprobar que lo abierto es un fichero regular del usuario actual:
	// O_NOFOLLOW protege del symlink, pero no de un dispositivo/FIFO.
	if fi, statErr := f.Stat(); statErr != nil {
		_ = f.Close()
		return nil, statErr
	} else if !fi.Mode().IsRegular() {
		_ = f.Close()
		return nil, fmt.Errorf("el lockfile %s no es un fichero regular", socketPath+".lock")
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		_ = f.Close()
		if errors.Is(err, syscall.EAGAIN) || errors.Is(err, syscall.EWOULDBLOCK) || errors.Is(err, syscall.EACCES) {
			return nil, fmt.Errorf("%w: %s", ErrAlreadyRunning, socketPath)
		}
		return nil, err
	}
	return f, nil
}

func NewServer(registry *Registry, connMon *connectivity.Monitor) *Server {
	path, pathErr := ipc.DefaultSocketPath()
	s := &Server{
		path:      path,
		pathErr:   pathErr,
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

// SetLockFile permite inyectar un bloqueo adquirido previamente (por ejemplo en main).
func (s *Server) SetLockFile(f *os.File) {
	s.lockFile = f
}

// Start arranca el servidor y bloquea hasta que el contexto se cancele.
// Al cancelarse (SIGTERM/SIGINT), cierra todos los clientes activos y espera
// a que terminen los pumps antes de salir (graceful shutdown).
func (s *Server) Start(ctx context.Context) error {
	if s.pathErr != nil {
		return s.pathErr
	}
	// Crear/validar el directorio del socket (puede ser otro si se
	// redefinió con SHINRO_SOCKET_PATH). La validación impide que otro
	// usuario coloque un socket o un lockfile en nuestro nombre.
	if dir := filepath.Dir(s.path); dir != "" && dir != "." {
		if err := ipc.EnsurePrivateDir(dir); err != nil {
			return err
		}
	}

	// Adquirir el lockfile exclusivo si no fue inyectado previamente desde main.
	// Esto previene condiciones de carrera TOCTOU en caso de inicios simultáneos
	// y valida atómicamente si otro proceso ya posee el socket en 0 ms.
	if s.lockFile == nil {
		lock, err := AcquireLock(s.path)
		if err != nil {
			return err
		}
		s.lockFile = lock
	}

	_ = os.Remove(s.path)
	ln, err := net.Listen("unix", s.path)
	if err != nil {
		s.lockFile.Close()
		s.lockFile = nil
		return err
	}
	s.listener = ln
	if err := os.Chmod(s.path, 0600); err != nil {
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
	s.shutdownMu.Lock()
	s.stopping.Store(true)
	s.shutdownMu.Unlock()

	// Dejar de aceptar conexiones lo antes posible para evitar fugas de
	// clientes aceptados durante el apagado.
	if s.listener != nil {
		_ = s.listener.Close()
	}

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

	// Barrido final: si una conexión entró en la ventana entre el snapshot
	// anterior y el cierre del listener, cerrarla aquí.
	s.mu.Lock()
	late := make([]*client, 0, len(s.clients))
	for c := range s.clients {
		late = append(late, c)
	}
	s.mu.Unlock()
	for _, c := range late {
		c.close()
	}

	// Esperar a que los readLoops retiren los clientes cerrados del mapa.
	drainDeadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(drainDeadline) {
		s.mu.Lock()
		n := len(s.clients)
		s.mu.Unlock()
		if n == 0 {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}

	if s.connMon != nil {
		if err := s.connMon.Close(); err != nil {
			logger.Warn("error cerrando monitor de conectividad", "error", err)
		}
	}

	// Borrar el socket antes de soltar el flock: así no se puede deslinkear
	// el socket de un daemon de reemplazo que arranque tras liberar el lock.
	_ = os.Remove(s.path)
	if s.lockFile != nil {
		s.lockFile.Close()
		s.lockFile = nil
	}
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
	pumpUpdStarted bool

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
		// Cliente lento o saturado: cerrarlo en vez de descartar mensajes
		// silenciosamente. Un cliente que no drena su cola no debe poder
		// retener memoria del daemon ni dejar a los módulos creyendo que
		// el envío funcionó.
		putBuf(msg)
		logger.Warn("cliente saturado, cerrando conexión", "addr", c.conn.RemoteAddr())
		c.close()
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

const (
	// maxClients limita la cantidad de conexiones simultáneas. Cada una
	// reserva una goroutine de lectura y otra de escritura; sin tope, un
	// cliente puede agotar los descriptores y la memoria del daemon.
	maxClients = 64

	// handshakeTimeout es el plazo para recibir el primer mensaje tras
	// conectar. Los clientes reales (QML, CLI) envían hello o get de
	// inmediato; una conexión inactiva se cierra antes de consumir recursos.
	handshakeTimeout = 5 * time.Second

	// writeTimeout es el plazo para cada escritura al cliente. Un cliente
	// que no drena su cola (Slowloris) se cierra en vez de bloquear al
	// daemon.
	writeTimeout = 10 * time.Second

	// maxSendQueue es el tamaño de la cola de salida por cliente. Se ha
	// recortado desde 128: un cliente sano no acumula mensajes.
	maxSendQueue = 32
)

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
			logger.Warn("error aceptando conexión", "error", err)
			if !sleepCtx(ctx, 100*time.Millisecond) {
				return
			}
			continue
		}

		if s.stopping.Load() {
			_ = conn.Close()
			continue
		}

		if !isAuthorizedPeer(conn) {
			logger.Warn("conexión rechazada: peer no autorizado", "addr", conn.RemoteAddr())
			_ = conn.Close()
			continue
		}

		// Plazo de handshake: se limpia en readLoop al recibir el primer
		// mensaje válido. Evita conexiones que se cuelgan sin enviar nada.
		_ = conn.SetReadDeadline(time.Now().Add(handshakeTimeout))

		c := &client{
			conn:   conn,
			reader: bufio.NewReader(conn),
			send:   make(chan []byte, maxSendQueue),
			done:   make(chan struct{}),
			server: s,
		}

		s.mu.Lock()
		if s.stopping.Load() || len(s.clients) >= maxClients {
			s.mu.Unlock()
			if s.stopping.Load() {
				_ = conn.Close()
			} else {
				logger.Warn("límite de clientes alcanzado, rechazando", "addr", conn.RemoteAddr())
				_ = conn.Close()
			}
			continue
		}
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
			// Drenar la cola para devolver los buffers al pool antes de salir.
			for {
				select {
				case msg := <-c.send:
					putBuf(msg)
				default:
					return
				}
			}
		case msg := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeTimeout))
			_, err := c.conn.Write(msg)
			putBuf(msg)
			if err != nil {
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
		if err := encodingjsonv2.Unmarshal([]byte(line), &raw, jsonv2Options); err != nil {
			logger.Warn("no se pudo parsear JSON", "addr", c.conn.RemoteAddr(), "error", err, "bytes", len(line))
			continue
		}

		var msgType string
		_ = encodingjsonv2.Unmarshal(raw["type"], &msgType, jsonv2Options)

		switch msgType {
		case "hello", "get":
			// Primer mensaje válido: levantar el plazo de handshake. Solo se
			// quita tras un mensaje de protocolo reconocido; líneas vacías,
			// JSON inválido o tipos desconocidos mantienen el deadline para
			// evitar que una conexión pre-handshake ocupe un slot para siempre.
			_ = c.conn.SetReadDeadline(time.Time{})
			if msgType == "hello" {
				s.handleHello(c, raw)
			} else {
				s.handleGet(c, raw)
			}
		default:
			if msgType == "" {
				logger.Warn("tipo de mensaje no especificado o inválido")
			} else {
				logger.Warn("mensaje desconocido", "type", truncateForLog(msgType, 128))
			}
		}
	}
}

// maxClientLineBytes es el tamaño máximo de una línea JSON recibida.
//
// Sin tope, un cliente (o un bug) podría mandar una línea enorme y hacer
// crecer la memoria del daemon sin límite: el daemon es un proceso de larga
// vida y no puede depender de que todos sus clientes se porten bien.
const maxClientLineBytes = 1 << 20 // 1 MiB
const maxDiscardBytes = 8 << 20    // 8 MiB: tope al drenar una línea gigante

// errLineTooLong indica que la línea recibida supera el máximo permitido.
var errLineTooLong = errors.New("línea demasiado larga")

// isAuthorizedPeer verifica mediante credenciales de socket Unix (SO_PEERCRED)
// que el proceso conectado pertenece al mismo UID del dueño del daemon o a root.
func isAuthorizedPeer(conn net.Conn) bool {
	uconn, ok := conn.(*net.UnixConn)
	if !ok {
		// Fail-closed: solo se aceptan sockets Unix reales, cuyas
		// credenciales se puedan verificar por SO_PEERCRED.
		return false
	}
	raw, err := uconn.SyscallConn()
	if err != nil {
		return false
	}
	var cred *syscall.Ucred
	var credErr error
	err = raw.Control(func(fd uintptr) {
		cred, credErr = syscall.GetsockoptUcred(int(fd), syscall.SOL_SOCKET, syscall.SO_PEERCRED)
	})
	if err != nil || credErr != nil || cred == nil {
		return false
	}
	uid := uint32(os.Getuid())
	return cred.Uid == uid || cred.Uid == 0
}

// readClientLine lee una línea terminada en '\n' con un tope de tamaño.
//
// Si la línea es demasiado larga, se consume el resto hasta el fin de línea
// (para no desincronizar el stream) con un tope máximo para evitar Slowloris,
// y se devuelve errLineTooLong.
func readClientLine(r *bufio.Reader) (string, error) {
	var sb strings.Builder
	total := 0
	tooLong := false
	for {
		chunk, err := r.ReadSlice('\n')
		total += len(chunk)
		if !tooLong {
			if total > maxClientLineBytes {
				tooLong = true
				sb.Reset()
			} else {
				sb.Write(chunk)
			}
		}
		if err == bufio.ErrBufferFull {
			if tooLong && total > maxDiscardBytes {
				return "", errLineTooLong
			}
			continue
		}
		if err != nil {
			return "", err
		}
		if tooLong {
			return "", errLineTooLong
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
			Lat  float64  `json:"lat"`
			Lon  float64  `json:"lon"`
		}
		if err := encodingjsonv2.Unmarshal(locRaw, &loc, jsonv2Options); err == nil {
			c.mu.Lock()
			if loc.Mode != "" {
				c.mode = loc.Mode
			}
			if loc.City != "" {
				c.city = loc.City
			}
			c.mu.Unlock()
		} else {
			logger.Debug("hello: ubicación inválida", "error", err)
		}
	}

	c.mu.Lock()
	mode := c.mode
	city := c.city
	c.mu.Unlock()

	resp, _ := encodingjsonv2.Marshal(map[string]any{
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
		_ = encodingjsonv2.Unmarshal(modRaw, &module, jsonv2Options)
	}
	logger.Debug("get request", "client", c.conn.RemoteAddr(), "module", truncateForLog(module, 128))

	if module == "" {
		s.sendError(c, "módulo no especificado")
		return
	}

	m := s.registry.Get(module)
	if m == nil {
		s.sendError(c, "módulo desconocido: "+truncateForLog(module, 128))
		return
	}

	inicio := time.Now()
	err := m.HandleGet(c, raw)
	if !errors.Is(err, errSkipHealthRecord) {
		s.recordModuleResult(module, err, time.Since(inicio))
	}
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
	for range intentos {
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

// WakeUpdateClients empuja el estado de actualizaciones a todos los clientes
// suscritos. El módulo lo usa para avisar del progreso (comprobando,
// actualizando) sin esperar al siguiente tick.
func (s *Server) WakeUpdateClients() {
	s.mu.Lock()
	clients := make([]*client, 0, len(s.clients))
	for c := range s.clients {
		if c.isSubscribed("updates") {
			clients = append(clients, c)
		}
	}
	s.mu.Unlock()

	m := s.registry.Get("updates")
	ss, ok := m.(snapshotSender)
	if !ok {
		return
	}

	for _, c := range clients {
		const intentos = 3
		var err error
		for range intentos {
			err = ss.SendSnapshot(c)
			if err == nil {
				break
			}
			time.Sleep(10 * time.Millisecond)
		}
		if err != nil {
			logger.Warn("updates: error enviando estado", "client", c.conn.RemoteAddr(), "error", err)
		}
	}
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
			// Desactivado: no se sale del pump, porque entonces el flag
			// pumpXStarted quedaría true y no se podría volver a arrancar.
			// Se bloquea hasta que se vuelva a suscribir (wake) o se vaya
			// el cliente (done).
			select {
			case <-done:
				return
			case <-c.modWake(m.Name()):
				continue
			}
		}

		if interval > 86400 {
			interval = 86400
		}
		wake := c.modWake(m.Name())
		timer := time.NewTimer(time.Duration(interval) * time.Second)
		select {
		case <-done:
			timer.Stop()
			return
		case <-wake:
			timer.Stop()
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
	s.shutdownMu.Lock()
	if s.stopping.Load() {
		s.shutdownMu.Unlock()
		return
	}
	s.pumpsWG.Add(1)
	s.shutdownMu.Unlock()

	safe.Go("socket.pump."+m.Name(), func() {
		defer s.pumpsWG.Done()
		pumpModule(m, c, c.done)
	})
}

// truncateForLog recorta una cadena a n caracteres (runes) para evitar spam y
// amplificación en los logs cuando un cliente envía valores enormes.
func truncateForLog(s string, n int) string {
	if n <= 0 {
		return s
	}
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n]) + "…"
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
