// Package connectivity detecta cambios de conectividad a Internet.
//
// Por defecto intenta usar NetworkManager D-Bus del sistema como fuente
// principal (señales en tiempo real, sin polling). Si NetworkManager no está
// disponible, cae a polling HTTP ligero a una URL de control.
//
// Cuando la conectividad cambia (offline -> online o viceversa) avisa a los
// suscriptores por un canal, para que el backend pueda refrescar los datos
// que dependen de la red (clima) sin esperar al siguiente tick programado.
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
	checkURL string
	interval time.Duration
	client   *http.Client

	nm *nmMonitor // nil si NetworkManager no está disponible

	mu    sync.Mutex
	state State
	subs  map[chan State]struct{}
}

// newTransport crea un transporte HTTP reutilizable con keep-alive.
func newTransport() *http.Transport {
	return &http.Transport{
		MaxIdleConns:        10,
		MaxIdleConnsPerHost: 2,
		IdleConnTimeout:     60 * time.Second,
	}
}

// New crea un monitor. Intenta usar NetworkManager D-Bus como fuente
// principal. Si no está disponible, usará polling HTTP a checkURL cuando se
// llame a Run.
// Si checkURL está vacía se usa un endpoint de Open-Meteo;
// si interval <= 0 se usan 30 segundos.
func New(checkURL string, interval time.Duration) *Monitor {
	if checkURL == "" {
		checkURL = "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0&current=temperature_2m"
	}
	if interval <= 0 {
		interval = 30 * time.Second
	}

	m := &Monitor{
		checkURL: checkURL,
		interval: interval,
		client:   &http.Client{Timeout: 5 * time.Second, Transport: newTransport()},
		state:    StateUnknown,
		subs:     make(map[chan State]struct{}),
	}

	// Intentar usar NetworkManager como fuente principal.
	m.nm = newNMMonitor()
	if m.nm != nil {
		logger.Info("conectividad", "fuente", "networkmanager-dbus")
	} else {
		logger.Info("conectividad", "fuente", "polling-http", "interval", interval)
	}

	return m
}

// Run ejecuta el bucle de monitoreo hasta que se cancele el contexto.
// Usa NetworkManager si está disponible, polling HTTP en caso contrario.
func (m *Monitor) Run(ctx context.Context) {
	if m.nm != nil {
		m.runNM(ctx)
	} else {
		m.runPolling(ctx)
	}
}

// runNM ejecuta el bucle usando NetworkManager como fuente de eventos.
func (m *Monitor) runNM(ctx context.Context) {
	ch := m.nm.Subscribe()
	defer m.nm.Unsubscribe(ch)

	for {
		select {
		case <-ctx.Done():
			return
		case nmState := <-ch:
			online := nmState == nmConnectivityFull
			m.updateState(online, nmStateString(nmState))
		}
	}
}

// runPolling ejecuta el bucle de comprobación HTTP periódica.
func (m *Monitor) runPolling(ctx context.Context) {
	for {
		online := m.check()
		m.updateState(online, "polling")

		select {
		case <-ctx.Done():
			return
		case <-time.After(m.interval):
		}
	}
}

// check devuelve true si la URL de control responde con 2xx.
func (m *Monitor) check() bool {
	req, err := http.NewRequest(http.MethodGet, m.checkURL, nil)
	if err != nil {
		return false
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Cache-Control", "no-cache")
	resp, err := m.client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body) // libera la conexión HTTP
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
	subs := make([]chan State, 0, len(m.subs))
	for ch := range m.subs {
		subs = append(subs, ch)
	}
	m.mu.Unlock()

	if m.state != prev {
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
