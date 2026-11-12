// Package connectivity detecta cambios de conectividad a Internet.
//
// Por defecto combina NetworkManager D-Bus del sistema como fuente de eventos
// instantáneos en tiempo real con una verificación HTTP ligera a un endpoint de control.
// Si NetworkManager no está disponible, realiza comprobaciones periódicas HTTP.
//
// Cuando la conectividad cambia (offline -> online o viceversa) avisa a los
// suscriptores por un canal, para que el backend pueda refrescar los datos
// que dependen de la red (clima) de inmediato sin esperar al siguiente tick.
package connectivity

import (
	"context"
	"io"
	"net/http"
	"sync"
	"time"

	"shinro-backend/internal/logger"
)

// State representa el estado de conectividad detectado.
type State int

const (
	StateUnknown State = iota
	StateOnline
	StateOffline
)

func (s State) String() string {
	switch s {
	case StateOnline:
		return "online"
	case StateOffline:
		return "offline"
	default:
		return "unknown"
	}
}

// Monitor vigila la conectividad y emite el estado en cada cambio.
type Monitor struct {
	checkURL    string
	fallbackURL string
	interval    time.Duration
	client      *http.Client

	nm *nmMonitor // nil si NetworkManager no está disponible

	mu           sync.Mutex
	state        State
	subs         map[chan State]struct{}
	forceCheckCh chan struct{}
}

// newTransport crea un transporte HTTP reutilizable con keep-alive.
func newTransport() *http.Transport {
	return &http.Transport{
		MaxIdleConns:        10,
		MaxIdleConnsPerHost: 2,
		IdleConnTimeout:     30 * time.Second,
	}
}

// New crea un monitor de conectividad.
// Intenta usar NetworkManager D-Bus para eventos en tiempo real.
// Si checkURL está vacía se usa un endpoint de conectividad ligero y confiable;
// si interval <= 0 se usan 30 segundos.
func New(checkURL string, interval time.Duration) *Monitor {
	fallback := ""
	if checkURL == "" {
		checkURL = "http://www.google.com/generate_204"
		fallback = "http://ping.archlinux.org/nm-check.txt"
	}
	if interval <= 0 {
		interval = 30 * time.Second
	}

	m := &Monitor{
		checkURL:     checkURL,
		fallbackURL:  fallback,
		interval:     interval,
		client:       &http.Client{Timeout: 4 * time.Second, Transport: newTransport()},
		state:        StateUnknown,
		subs:         make(map[chan State]struct{}),
		forceCheckCh: make(chan struct{}, 1),
	}

	// Intentar usar NetworkManager como fuente de eventos en tiempo real.
	m.nm = newNMMonitor()
	if m.nm != nil {
		logger.Info("conectividad", "fuente", "networkmanager-dbus+http", "check_url", m.checkURL)
	} else {
		logger.Info("conectividad", "fuente", "polling-http", "interval", interval, "check_url", m.checkURL)
	}

	return m
}

// Run ejecuta el bucle de monitoreo hasta que se cancele el contexto.
func (m *Monitor) Run(ctx context.Context) {
	if m.nm != nil {
		m.runNM(ctx)
	} else {
		m.runPolling(ctx)
	}
}

// runNM ejecuta el bucle reactivo usando NetworkManager más verificación y heartbeat.
func (m *Monitor) runNM(ctx context.Context) {
	ch := m.nm.Subscribe()
	defer m.nm.Unsubscribe(ch)

	// Verificación inicial inmediata
	m.verifyAndSetState("nm-init")

	ticker := time.NewTicker(m.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case nmOnline := <-ch:
			if !nmOnline {
				// Desconexión inmediata de NetworkManager: pasar a offline al instante
				m.updateState(false, "networkmanager-down")
			} else {
				// Señal de conexión: verificar internet de inmediato
				m.verifyAndSetState("networkmanager-up")
			}
		case <-ticker.C:
			// Heartbeat periódico para detectar pérdidas o recuperaciones de WAN no señaladas
			m.verifyAndSetState("heartbeat")
		case <-m.forceCheckCh:
			m.verifyAndSetState("manual-check")
		}
	}
}

// runPolling ejecuta el bucle de comprobación periódica cuando NetworkManager no está disponible.
func (m *Monitor) runPolling(ctx context.Context) {
	m.verifyAndSetState("polling-init")

	ticker := time.NewTicker(m.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			m.verifyAndSetState("polling")
		case <-m.forceCheckCh:
			m.verifyAndSetState("manual-check")
		}
	}
}

// verifyAndSetState realiza la comprobación de conectividad y actualiza el estado.
func (m *Monitor) verifyAndSetState(source string) {
	// Si NM afirma estar desconectado sin ambigüedad, marcar offline directamente
	if m.nm != nil && m.nm.isDefinitelyOffline() {
		m.updateState(false, source+"(nm-offline)")
		return
	}

	online := m.check()
	m.updateState(online, source)
}

// check devuelve true si el endpoint de control responde correctamente (2xx).
func (m *Monitor) check() bool {
	if m.checkURLWith(m.checkURL) {
		return true
	}
	if m.fallbackURL != "" && m.checkURLWith(m.fallbackURL) {
		return true
	}
	return false
}

func (m *Monitor) checkURLWith(u string) bool {
	req, err := http.NewRequest(http.MethodGet, u, nil)
	if err != nil {
		return false
	}
	req.Header.Set("User-Agent", "shinro-connectivity/1.0")
	req.Header.Set("Cache-Control", "no-cache")
	resp, err := m.client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)
	return resp.StatusCode >= 200 && resp.StatusCode < 300
}

// updateState actualiza el estado interno y notifica a los suscriptores si cambió.
func (m *Monitor) updateState(online bool, source string) {
	m.mu.Lock()
	prev := m.state
	if online {
		m.state = StateOnline
	} else {
		m.state = StateOffline
	}
	changed := m.state != prev
	subs := make([]chan State, 0, len(m.subs))
	for ch := range m.subs {
		subs = append(subs, ch)
	}
	m.mu.Unlock()

	if changed {
		logger.Info("conectividad", "prev", prev, "current", m.state, "fuente", source)
		for _, ch := range subs {
			select {
			case ch <- m.state:
			default:
				// Suscriptor lento: no bloquear el monitor.
			}
		}
	}
}

// CheckNow solicita una verificación de conectividad inmediata.
func (m *Monitor) CheckNow() {
	select {
	case m.forceCheckCh <- struct{}{}:
	default:
	}
}

// ReportSuccess puede ser llamado cuando una petición externa (p. ej. clima)
// tuvo éxito comprobado con Internet, actualizando el estado de inmediato a Online.
func (m *Monitor) ReportSuccess() {
	m.updateState(true, "external-success")
}

// Subscribe devuelve un canal que recibe el estado cada vez que cambia.
// También se envía el estado actual de inmediato al suscribirse.
func (m *Monitor) Subscribe() chan State {
	ch := make(chan State, 1)
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
func (m *Monitor) Unsubscribe(ch chan State) {
	m.mu.Lock()
	delete(m.subs, ch)
	m.mu.Unlock()
}

// State devuelve el estado actual conocido.
func (m *Monitor) State() State {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.state
}

// IsOnline devuelve true si el estado actual es online.
func (m *Monitor) IsOnline() bool {
	return m.State() == StateOnline
}

// Close cierra los recursos del monitor (conexión D-Bus si se usa NM).
func (m *Monitor) Close() error {
	if m.nm != nil {
		return m.nm.Close()
	}
	return nil
}

// compilo-check de interfaz.
var (
	_ interface{ Run(context.Context) }   = (*Monitor)(nil)
	_ interface{ Subscribe() chan State } = (*Monitor)(nil)
	_ interface{ Close() error }          = (*Monitor)(nil)
)
