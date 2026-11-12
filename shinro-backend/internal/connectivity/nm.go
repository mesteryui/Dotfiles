package connectivity

import (
	"fmt"
	"os"
	"sync"

	"github.com/godbus/dbus/v5"

	"shinro-backend/internal/logger"
)

// Estados de conectividad de NetworkManager (propiedad Connectivity).
const (
	nmConnectivityUnknown uint32 = 0
	nmConnectivityNone    uint32 = 1
	nmConnectivityPortal  uint32 = 2
	nmConnectivityLimited uint32 = 3
	nmConnectivityFull    uint32 = 4
)

// Estados de conexión de NetworkManager (propiedad State y señal StateChanged).
const (
	nmStateUnknown         uint32 = 0
	nmStateAsleep          uint32 = 10
	nmStateDisconnected    uint32 = 20
	nmStateDisconnecting   uint32 = 30
	nmStateConnecting      uint32 = 40
	nmStateConnectedLocal  uint32 = 50
	nmStateConnectedSite   uint32 = 60
	nmStateConnectedGlobal uint32 = 70
)

// nmMonitor vigila la conectividad a través de NetworkManager D-Bus.
type nmMonitor struct {
	conn   *dbus.Conn
	object dbus.BusObject

	mu           sync.Mutex
	connectivity uint32
	state        uint32
	lastOnline   bool
	subs         map[chan bool]struct{}
}

// newNMMonitor intenta conectar al bus de sistema y suscribirse a NetworkManager.
// Devuelve nil si NetworkManager no está disponible o si la variable de entorno
// SHINRO_CONNECTIVITY_DISABLE_NM está establecida (para tests o sin NM).
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
		conn:         conn,
		object:       obj,
		connectivity: nmConnectivityUnknown,
		state:        nmStateUnknown,
		subs:         make(map[chan bool]struct{}),
	}

	// Suscribirse a las señales de NetworkManager con reglas AddMatchSignal.
	m.subscribeSignals()

	// Leer el estado inicial inmediatamente.
	m.readInitialState()

	return m
}

// subscribeSignals añade reglas de coincidencia D-Bus y escucha StateChanged y PropertiesChanged.
func (m *nmMonitor) subscribeSignals() {
	_ = m.conn.AddMatchSignal(
		dbus.WithMatchSender("org.freedesktop.NetworkManager"),
		dbus.WithMatchInterface("org.freedesktop.NetworkManager"),
		dbus.WithMatchMember("StateChanged"),
	)
	_ = m.conn.AddMatchSignal(
		dbus.WithMatchSender("org.freedesktop.NetworkManager"),
		dbus.WithMatchInterface("org.freedesktop.DBus.Properties"),
		dbus.WithMatchMember("PropertiesChanged"),
		dbus.WithMatchPathNamespace("/org/freedesktop/NetworkManager"),
	)

	signalCh := make(chan *dbus.Signal, 20)
	m.conn.Signal(signalCh)

	go func() {
		for sig := range signalCh {
			if sig == nil {
				return
			}
			switch sig.Name {
			case "org.freedesktop.NetworkManager.StateChanged":
				if len(sig.Body) > 0 {
					if st, ok := sig.Body[0].(uint32); ok {
						m.handleStateChanged(st)
					}
				}
			case "org.freedesktop.DBus.Properties.PropertiesChanged":
				if len(sig.Body) >= 2 {
					if iface, ok := sig.Body[0].(string); ok && iface == "org.freedesktop.NetworkManager" {
						if props, ok := sig.Body[1].(map[string]dbus.Variant); ok {
							m.handlePropertiesChanged(props)
						}
					}
				}
			}
		}
	}()
}

// readInitialState lee Connectivity y State síncronamente al inicio.
func (m *nmMonitor) readInitialState() {
	var connVal uint32
	callConn := m.object.Call("org.freedesktop.DBus.Properties.Get", 0,
		"org.freedesktop.NetworkManager", "Connectivity")
	if callConn.Err == nil {
		_ = callConn.Store(&connVal)
	}

	var stateVal uint32
	callState := m.object.Call("org.freedesktop.DBus.Properties.Get", 0,
		"org.freedesktop.NetworkManager", "State")
	if callState.Err == nil {
		_ = callState.Store(&stateVal)
	}

	m.mu.Lock()
	m.connectivity = connVal
	m.state = stateVal
	online := m.evalOnline()
	m.lastOnline = online
	m.mu.Unlock()

	logger.Debug("networkmanager estado inicial",
		"connectivity", nmConnectivityString(connVal),
		"state", nmStateString(stateVal),
		"online", online,
	)
}

func (m *nmMonitor) handleStateChanged(st uint32) {
	m.mu.Lock()
	m.state = st
	online := m.evalOnline()
	prev := m.lastOnline
	m.lastOnline = online
	m.mu.Unlock()

	logger.Debug("networkmanager StateChanged", "state", nmStateString(st), "online", online)
	if online != prev {
		m.notify(online)
	}
}

func (m *nmMonitor) handlePropertiesChanged(props map[string]dbus.Variant) {
	m.mu.Lock()
	changed := false
	if v, ok := props["Connectivity"]; ok {
		if val, ok := v.Value().(uint32); ok {
			m.connectivity = val
			changed = true
		}
	}
	if v, ok := props["State"]; ok {
		if val, ok := v.Value().(uint32); ok {
			m.state = val
			changed = true
		}
	}
	if !changed {
		m.mu.Unlock()
		return
	}

	online := m.evalOnline()
	prev := m.lastOnline
	m.lastOnline = online
	m.mu.Unlock()

	logger.Debug("networkmanager PropertiesChanged",
		"connectivity", nmConnectivityString(m.connectivity),
		"state", nmStateString(m.state),
		"online", online,
	)
	if online != prev {
		m.notify(online)
	}
}

// evalOnline determina si según NetworkManager se cuenta con conectividad a Internet.
// Debe llamarse con m.mu bloqueado.
func (m *nmMonitor) evalOnline() bool {
	if m.connectivity == nmConnectivityFull || m.state == nmStateConnectedGlobal {
		return true
	}
	return false
}

// isDefinitelyOffline indica si NM afirma estar desconectado o en captive portal.
func (m *nmMonitor) isDefinitelyOffline() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.state <= nmStateDisconnected || m.connectivity == nmConnectivityNone || m.connectivity == nmConnectivityPortal
}

// notify avisa a todos los suscriptores del nuevo estado online.
func (m *nmMonitor) notify(online bool) {
	m.mu.Lock()
	subs := make([]chan bool, 0, len(m.subs))
	for ch := range m.subs {
		subs = append(subs, ch)
	}
	m.mu.Unlock()

	for _, ch := range subs {
		select {
		case ch <- online:
		default:
			// No bloquear si el canal está lleno
		}
	}
}

// Subscribe devuelve un canal que recibe si está online o no cada vez que cambia.
// Se envía el estado actual de inmediato al suscribirse.
func (m *nmMonitor) Subscribe() chan bool {
	ch := make(chan bool, 1)
	m.mu.Lock()
	m.subs[ch] = struct{}{}
	online := m.evalOnline()
	m.mu.Unlock()

	select {
	case ch <- online:
	default:
	}
	return ch
}

// Unsubscribe cancela una suscripción previa.
func (m *nmMonitor) Unsubscribe(ch chan bool) {
	m.mu.Lock()
	delete(m.subs, ch)
	m.mu.Unlock()
}

// IsOnline devuelve si NetworkManager considera que hay conexión global.
func (m *nmMonitor) IsOnline() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.evalOnline()
}

// CheckConnectivity solicita a NetworkManager reevaluar la conectividad de red.
func (m *nmMonitor) CheckConnectivity() (uint32, error) {
	var conn uint32
	call := m.object.Call("org.freedesktop.NetworkManager.CheckConnectivity", 0)
	if call.Err != nil {
		return nmConnectivityUnknown, call.Err
	}
	if err := call.Store(&conn); err != nil {
		return nmConnectivityUnknown, err
	}
	m.mu.Lock()
	m.connectivity = conn
	online := m.evalOnline()
	prev := m.lastOnline
	m.lastOnline = online
	m.mu.Unlock()

	if online != prev {
		m.notify(online)
	}
	return conn, nil
}

// Close cierra la conexión D-Bus.
func (m *nmMonitor) Close() error {
	m.mu.Lock()
	m.subs = make(map[chan bool]struct{})
	m.mu.Unlock()
	return m.conn.Close()
}

func nmConnectivityString(conn uint32) string {
	switch conn {
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
		return fmt.Sprintf("unknown(%d)", conn)
	}
}

func nmStateString(state uint32) string {
	switch state {
	case nmStateUnknown:
		return "unknown"
	case nmStateAsleep:
		return "asleep"
	case nmStateDisconnected:
		return "disconnected"
	case nmStateDisconnecting:
		return "disconnecting"
	case nmStateConnecting:
		return "connecting"
	case nmStateConnectedLocal:
		return "connected_local"
	case nmStateConnectedSite:
		return "connected_site"
	case nmStateConnectedGlobal:
		return "connected_global"
	default:
		return fmt.Sprintf("state(%d)", state)
	}
}
