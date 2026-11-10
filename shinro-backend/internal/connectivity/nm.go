package connectivity

import (
	"fmt"
	"os"
	"sync"

	"github.com/godbus/dbus/v5"

	"shinro-backend/internal/logger"
)

// Estado de conectividad de NetworkManager.
const (
	nmConnectivityUnknown = 0
	nmConnectivityNone    = 1
	nmConnectivityPortal  = 2
	nmConnectivityLimited = 3
	nmConnectivityFull    = 4
)

// nmMonitor vigila la conectividad a través de NetworkManager D-Bus.
type nmMonitor struct {
	conn   *dbus.Conn
	object dbus.BusObject

	mu    sync.Mutex
	state int // último estado conocido de Connectivity
	subs  map[chan int]struct{}
}

// newNMMonitor intenta conectar al bus de sistema y suscribirse a NetworkManager.
// Devuelve nil si NetworkManager no está disponible o si la variable de entorno
// SHINRO_CONNECTIVITY_DISABLE_NM está establecida (para forzar polling en tests).
func newNMMonitor() *nmMonitor {
	if os.Getenv("SHINRO_CONNECTIVITY_DISABLE_NM") == "1" {
		return nil
	}

	conn, err := dbus.SystemBus()
	if err != nil {
		logger.Warn("networkmanager: no se pudo conectar al bus de sistema", "error", err)
		return nil
	}

	obj := conn.Object("org.freedesktop.NetworkManager", dbus.ObjectPath("/org/freedesktop/NetworkManager"))

	m := &nmMonitor{
		conn:   conn,
		object: obj,
		state:  nmConnectivityUnknown,
		subs:   make(map[chan int]struct{}),
	}

	// Suscribirse a la señal StateChanged del manager.
	m.subscribeSignals()

	// Leer el estado inicial.
	go m.readInitialState()

	return m
}

// subscribeSignals se suscribe a las señales de NetworkManager.
func (m *nmMonitor) subscribeSignals() {
	signal := make(chan *dbus.Signal, 10)
	m.conn.Signal(signal)
	go func() {
		for sig := range signal {
			if sig.Name == "org.freedesktop.NetworkManager.StateChanged" {
				if len(sig.Body) > 0 {
					if state, ok := sig.Body[0].(uint32); ok {
						m.notify(int(state))
					}
				}
			}
		}
	}()
}

// readInitialState lee la propiedad Connectivity al arrancar.
func (m *nmMonitor) readInitialState() {
	var connectivity uint32
	call := m.object.Call("org.freedesktop.DBus.Properties.Get", 0,
		"org.freedesktop.NetworkManager", "Connectivity")
	if call.Err != nil {
		logger.Warn("networkmanager: no se pudo leer propiedad Connectivity", "error", call.Err)
		return
	}
	if err := call.Store(&connectivity); err != nil {
		logger.Warn("networkmanager: no se pudo decodificar Connectivity", "error", err)
		return
	}
	m.notify(int(connectivity))
}

// notify avisa a todos los suscriptores del nuevo estado.
func (m *nmMonitor) notify(state int) {
	m.mu.Lock()
	prev := m.state
	m.state = state
	subs := make([]chan int, 0, len(m.subs))
	for ch := range m.subs {
		subs = append(subs, ch)
	}
	m.mu.Unlock()

	if state != prev {
		logger.Debug("networkmanager", "prev", prev, "current", state)
		for _, ch := range subs {
			select {
			case ch <- state:
			default:
				// Suscriptor lento: no bloquear.
			}
		}
	}
}

// Subscribe devuelve un canal que recibe el estado cada vez que cambia.
// También se envía el estado actual de inmediato al suscribirse.
func (m *nmMonitor) Subscribe() chan int {
	ch := make(chan int, 1)
	m.mu.Lock()
	m.subs[ch] = struct{}{}
	state := m.state
	m.mu.Unlock()

	select {
	case ch <- state:
	default:
	}
	return ch
}

// Unsubscribe cancela una suscripción previa.
func (m *nmMonitor) Unsubscribe(ch chan int) {
	m.mu.Lock()
	delete(m.subs, ch)
	m.mu.Unlock()
}

// State devuelve el estado actual conocido.
func (m *nmMonitor) State() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.state
}

// IsOnline devuelve true si el estado es CONNECTED_GLOBAL.
func (m *nmMonitor) IsOnline() bool {
	return m.State() == nmConnectivityFull
}

// nmStateString devuelve una representación legible del estado NM.
func nmStateString(state int) string {
	switch state {
	case nmConnectivityUnknown:
		return "unknown"
	case nmConnectivityNone:
		return "none"
	case nmConnectivityPortal:
		return "portal"
	case nmConnectivityLimited:
		return "limited"
	case nmConnectivityFull:
		return "full"
	default:
		return fmt.Sprintf("unknown(%d)", state)
	}
}

// Close cierra la conexión D-Bus.
func (m *nmMonitor) Close() error {
	m.mu.Lock()
	m.subs = make(map[chan int]struct{})
	m.mu.Unlock()
	return m.conn.Close()
}
