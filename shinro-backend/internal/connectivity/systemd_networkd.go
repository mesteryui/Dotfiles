package connectivity

import (
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"shinro-backend/internal/logger"
)

// systemdNetworkdMonitor vigila la conectividad usando systemd-networkd.
// Comprueba el estado de las interfaces, rutas por defecto y
// lee la configuración de systemd-networkd cuando NetworkManager no está
// disponible.
type systemdNetworkdMonitor struct {
	mu        sync.Mutex
	online    bool
	subs      map[chan bool]struct{}
	done      chan struct{}
	closeOnce sync.Once
	checked   bool // ya realizamos la primera comprobación de estado
}

// newSystemdNetworkdMonitor crea un nuevo monitor que usa systemd-networkd.
// Devuelve nil si no puede determinar el estado inicial (por ejemplo, cuando
// systemd-networkd no gestiona ninguna interfaz ni hay ruta por defecto). En
// ese caso el Monitor de conectividad cae a comprobación HTTP en lugar de
// declarar al sistema offline para siempre.
func newSystemdNetworkdMonitor() *systemdNetworkdMonitor {
	if os.Getenv("SHINRO_CONNECTIVITY_DISABLE_SDM") == "1" {
		return nil
	}

	// Comprobar si systemd-networkd está realmente activo en el sistema.
	// systemd-networkd crea /run/systemd/netif/ al iniciarse.
	if _, err := os.Stat("/run/systemd/netif"); err != nil {
		return nil
	}

	m := &systemdNetworkdMonitor{
		done: make(chan struct{}),
		subs: make(map[chan bool]struct{}),
	}

	// Leer estado inicial
	if !m.readInitialState() {
		logger.Warn("systemd-networkd", "no se pudo determinar el estado inicial; caerá en HTTP polling")
		return nil
	}
	logger.Info("systemd-networkd", "monitor", "activo")
	return m
}

// readInitialState lee el estado actual del sistema: rutas por defecto y
// estado de las interfaces de red. Devuelve true si logró obtener algo de
// información (ruta por defecto o interfaz no-loopback activa). Cuando no hay
// ninguna de las dos no marca `checked`, para que isDefinitelyOffline() no
// afirme que el sistema está offline antes de haber comprobado realmente por
// HTTP.
func (m *systemdNetworkdMonitor) readInitialState() bool {
	// Comprobar si hay una ruta por defecto
	if hasDefaultRoute() {
		m.mu.Lock()
		m.online = true
		m.checked = true
		m.mu.Unlock()
		return true
	}

	// Si no hay ruta por defecto, comprobar si hay interfaces arriba
	if InterfaceUp() {
		m.mu.Lock()
		m.online = true // hay interfaces, pero sin ruta por defecto quizá sea local
		m.checked = true
		m.mu.Unlock()
		return true
	}

	// No hay información disponible aún: no afirmar offline prematuramente.
	m.mu.Lock()
	m.online = false
	m.checked = false
	m.mu.Unlock()
	return false
}

var ipBinary = func() string {
	for _, p := range []string{"/usr/bin/ip", "/usr/sbin/ip", "/bin/ip", "/sbin/ip"} {
		if fi, err := os.Stat(p); err == nil && !fi.IsDir() {
			return p
		}
	}
	if p, err := exec.LookPath("ip"); err == nil {
		return p
	}
	return "ip"
}()

// hasDefaultRoute comprueba si hay una ruta por defecto activa (IPv4 o IPv6).
// Usa una sola ejecución de `ip` en lugar de una por familia de direcciones.
func hasDefaultRoute() bool {
	out, err := exec.Command(ipBinary, "route", "show", "default").Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), "default")
}

// InterfaceUp comprueba si al menos una interfaz de red principal está arriba.
func InterfaceUp() bool {
	out, err := exec.Command(ipBinary, "-brief", "link", "show").Output()
	if err != nil {
		return false
	}
	outStr := string(out)
	// Buscar interfaces que no sean LOOPBACK y que estén UP
	lines := strings.SplitSeq(outStr, "\n")
	for line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		name := fields[0]
		state := fields[1]
		// Saltar loopback
		if name == "lo" {
			continue
		}
		// Si el estado es "UP" o "LOWER_UP", la interfaz está activa
		if state == "UP" || state == "LOWER_UP" {
			return true
		}
	}
	return false
}

// evalOnline determina si el sistema tiene conectividad basándose en
// systemd-networkd: ruta por defecte + interfaces activas.
func (m *systemdNetworkdMonitor) evalOnline() bool {
	// Tener ruta por defecte es la señal más fuerte de conectividad
	if hasDefaultRoute() {
		return true
	}
	// Si no hay ruta por defecte, al menos necesitamos interfaces activas
	// (aunque podría ser solo local)
	if InterfaceUp() {
		return true
	}
	return false
}

// isDefinitelyOffline indica si systemd-networkd afirma estar desconectado.
//
// Si aún no hemos realizado la primera comprobación, no afirmamos que esté
// offline: preferimos una comprobación HTTP antes que declarar la conexión
// caída y quedarnos sin clima para siempre.
func (m *systemdNetworkdMonitor) isDefinitelyOffline() bool {
	m.mu.Lock()
	checked := m.checked
	m.mu.Unlock()
	// Si aún no hemos leído el estado inicial, no podemos afirmar offline.
	// Preferimos una comprobación HTTP antes que declarar la conexión caída
	// y quedarnos sin clima para siempre.
	if !checked {
		return false
	}
	// Si no hay ruta por defecto y no hay interfaces arriba, estamos offline.
	if !hasDefaultRoute() && !InterfaceUp() {
		return true
	}
	// Si hay ruta por defecto o interfaces arriba, no estamos definitivamente offline.
	return false
}

// Subscribe devuelve un canal que recibe si está online o no cada vez que cambia.
func (m *systemdNetworkdMonitor) Subscribe() chan bool {
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
func (m *systemdNetworkdMonitor) Unsubscribe(ch chan bool) {
	m.mu.Lock()
	delete(m.subs, ch)
	m.mu.Unlock()
}

// notify avisa a todos los suscriptores del nuevo estado online.
func (m *systemdNetworkdMonitor) notify(online bool) {
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
		}
	}
}

// Run ejecuta un bucle de monitoreo cada intervalo.
// Este método no bloquea: el llamador debe ejecutarlo en una goroutine.
func (m *systemdNetworkdMonitor) Run(interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	// Estado inicial
	m.notify(m.evalOnline())

	for {
		select {
		case <-ticker.C:
			online := m.evalOnline()
			m.mu.Lock()
			prev := m.online
			m.mu.Unlock()
			if online != prev {
				m.mu.Lock()
				m.online = online
				m.mu.Unlock()
				m.notify(online)
			}
		case <-m.done:
			return
		}
	}
}

// Close cierra el monitor.
func (m *systemdNetworkdMonitor) Close() error {
	m.closeOnce.Do(func() {
		if m.done != nil {
			close(m.done)
		}
	})
	m.mu.Lock()
	m.subs = make(map[chan bool]struct{})
	m.mu.Unlock()
	return nil
}

// State devuelve el estado actual.
func (m *systemdNetworkdMonitor) State() bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.online
}

// IsOnline devuelve true si el estado actual es online.
func (m *systemdNetworkdMonitor) IsOnline() bool {
	return m.State()
}

// compilo-check de interfaz.
var _ interface{ Subscribe() chan bool } = (*systemdNetworkdMonitor)(nil)
var _ interface{ Close() error } = (*systemdNetworkdMonitor)(nil)
