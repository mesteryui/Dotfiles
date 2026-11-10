// Package socket implementa el servidor Unix socket llamado "shinro".
// Este archivo define la interfaz Module y un registro que permite añadir
// nuevos módulos de datos (batería, red, audio...) solo implementando la
// interfaz y registrándola, sin tocar el bucle principal del servidor.
package socket

import (
	"encoding/json"
	"sync"

	"shinro-backend/internal/logger"
)

// Module es un módulo de datos que el servidor puede empujar a los clientes.
// Implementar esta interfaz permite añadir nuevos módulos sin modificar el
// servidor ni el protocolo de handshake.
type Module interface {
	// Name devuelve el identificador del módulo ("system", "weather", ...).
	Name() string

	// HandleHello procesa el handshake para este módulo. Devuelve true si el
	// cliente se suscribe a este módulo. El módulo puede usar c para leer la
	// configuración del handshake y debe devolver un canal de wake (puede ser
	// nil si no soporta despertares externos).
	HandleHello(c *client, raw map[string]json.RawMessage) (subscribed bool, wake <-chan struct{})

	// HandleGet responde a una petición puntual {"type":"get","module":<name>}.
	HandleGet(c *client, raw map[string]json.RawMessage)

	// SendUpdate envía una actualización inmediata al cliente.
	SendUpdate(c *client) error

	// Pump devuelve el intervalo en segundos (<= 0 = desactivado) y ejecuta el
	// bucle periódico hasta que done se cierre. wake despierta el bucle para
	// reevaluar el intervalo o forzar un envío inmediato.
	Pump(c *client, wake <-chan struct{}, done <-chan struct{})
}

// Registry guarda los módulos registrados por nombre.
type Registry struct {
	mu    sync.Mutex
	mods  map[string]Module
	order []string // orden de registro para pumps deterministas
}

// NewRegistry crea un registro vacío.
func NewRegistry() *Registry {
	return &Registry{
		mods:  make(map[string]Module),
		order: make([]string, 0),
	}
}

// Register añade un módulo al registro. Panic si se registra el mismo nombre dos veces.
func (r *Registry) Register(m Module) {
	r.mu.Lock()
	defer r.mu.Unlock()
	name := m.Name()
	if _, ok := r.mods[name]; ok {
		logger.Error("módulo duplicado", "module", name)
		panic("socket: módulo " + name + " ya registrado")
	}
	r.mods[name] = m
	r.order = append(r.order, name)
}

// Get devuelve el módulo por nombre, o nil si no existe.
func (r *Registry) Get(name string) Module {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.mods[name]
}

// Names devuelve los nombres de todos los módulos registrados, en orden.
func (r *Registry) Names() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]string, len(r.order))
	copy(out, r.order)
	return out
}

// Cada cliente necesita canales de wake y estado de arranque por módulo.
// Se almacenan en mapas indexados por nombre de módulo para ser genéricos.

func (c *client) modWake(name string) chan struct{} {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.modWakes == nil {
		c.modWakes = make(map[string]chan struct{})
	}
	ch, ok := c.modWakes[name]
	if !ok {
		ch = make(chan struct{}, 1)
		c.modWakes[name] = ch
	}
	return ch
}

func (c *client) signalMod(name string) {
	select {
	case c.modWake(name) <- struct{}{}:
	default:
	}
}

func (c *client) isModStarted(name string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.modStarted == nil {
		return false
	}
	return c.modStarted[name]
}

func (c *client) setModStarted(name string, started bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.modStarted == nil {
		c.modStarted = make(map[string]bool)
	}
	c.modStarted[name] = started
}

func (c *client) isSubscribed(name string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.subs == nil {
		return false
	}
	return c.subs[name]
}

func (c *client) setSubscribed(name string, sub bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.subs == nil {
		c.subs = make(map[string]bool)
	}
	if sub {
		c.subs[name] = true
	} else {
		delete(c.subs, name)
	}
}

func (c *client) modInterval(name string) int {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.modIntervals == nil {
		return 0
	}
	return c.modIntervals[name]
}

func (c *client) setModInterval(name string, seconds int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.modIntervals == nil {
		c.modIntervals = make(map[string]int)
	}
	c.modIntervals[name] = seconds
}

// ModPool es un pool de buffers para reutilizar en escrituras al socket.
var ModPool = sync.Pool{
	New: func() any {
		return make([]byte, 0, 4096)
	},
}

// writeBuf devuelve un mensaje con salto de línea usando un buffer del pool.
// El llamador debe escribirlo y no retener el slice.
func writeBuf(msg []byte) []byte {
	buf := ModPool.Get().([]byte)
	buf = buf[:0]
	buf = append(buf, msg...)
	buf = append(buf, '\n')
	return buf
}

// putBuf devuelve un buffer al pool.
func putBuf(buf []byte) {
	if cap(buf) <= 1<<20 {
		ModPool.Put(buf)
	}
}

// wakeMod despierta el pump de un módulo para un cliente.
func wakeMod(c *client, name string) {
	c.signalMod(name)
}

// sendErrorToClient envía un mensaje de error al cliente y lo registra.
// Se usa desde todos los módulos para evitar duplicar la misma lógica.
func sendErrorToClient(c *client, module string, message string) {
	msg, _ := json.Marshal(map[string]string{
		"type":    "error",
		"message": message,
	})
	c.write(writeBuf(msg))
	logger.Warn("error", "module", module, "client", c.conn.RemoteAddr(), "message", message)
}
