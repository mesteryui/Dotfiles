// Package connectivity detecta cambios de conectividad a Internet.
//
// Por defecto combina NetworkManager D-Bus del sistema como fuente de eventos
// instantáneos en tiempo real con una verificación HTTP ligera a un endpoint de control.
// Si NetworkManager no está disponible, usa systemd-networkd para detectar el estado
// de las interfaces y rutas, y como último recurso realiza comprobaciones HTTP periódicas.
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
	"shinro-backend/internal/safe"
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

	nm  *nmMonitor              // nil si NetworkManager no está disponible
	sdm *systemdNetworkdMonitor // nil si systemd-networkd no está disponible o se prefiere NM

	mu    sync.Mutex
	state State
	subs  map[chan State]struct{}

	// fuente indica qué mecanismo de red está activo actualmente.
	// Valores posibles: "networkmanager", "systemd-networkd", "http-polling"
	source string

	// checkMu coordina las comprobaciones HTTP, que se hacen en segundo
	// plano. seq se incrementa con cada decisión de estado: una
	// comprobación que empezó antes de la última decisión se descarta al
	// terminar, porque su resultado ya está obsoleto.
	//
	// pendingCheck marca que llegó un evento mientras había una comprobación
	// en curso: al terminar hay que repetirla para no perder ese evento.
	// pendingSource guarda de dónde vino ese evento, para que el registro
	// diga la verdad.
	checkMu      sync.Mutex
	checking     bool
	pendingCheck bool
	pendingSrc   string
	seq          uint64
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
// Si NetworkManager no está disponible, usa systemd-networkd para detectar
// el estado de las interfaces y rutas.
// Como último recurso, realiza comprobaciones HTTP periódicas.
//
// Si checkURL está vacía se usa un endpoint de conectividad ligero y confiable;
// si interval <= 0 se usan 30 segundos.
func New(checkURL string, interval time.Duration) *Monitor {
	fallback := ""
	if checkURL == "" {
		checkURL = "https://www.google.com/generate_204"
		fallback = "https://ping.archlinux.org/nm-check.txt"
	}
	if interval <= 0 {
		interval = 30 * time.Second
	}

	m := &Monitor{
		checkURL:    checkURL,
		fallbackURL: fallback,
		interval:    interval,
		client:      &http.Client{Timeout: 4 * time.Second, Transport: newTransport()},
		state:       StateUnknown,
		subs:        make(map[chan State]struct{}),
	}

	// Intentar usar NetworkManager como fuente de eventos en tiempo real.
	m.nm = newNMMonitor()
	if m.nm != nil {
		m.source = "networkmanager"
		logger.Info("conectividad", "fuente", "networkmanager-dbus+http+systemd", "check_url", m.checkURL)
	} else {
		// NetworkManager no disponible: intentar systemd-networkd
		m.sdm = newSystemdNetworkdMonitor()
		if m.sdm != nil {
			m.source = "systemd-networkd"
			logger.Info("conectividad", "fuente", "systemd-networkd+http", "check_url", m.checkURL)
		} else {
			// Ningún gestor de red disponible, usar HTTP polling
			m.source = "http-polling"
			logger.Info("conectividad", "fuente", "polling-http", "interval", interval, "check_url", m.checkURL)
		}
	}

	return m
}

// Run ejecuta el bucle de monitoreo hasta que se cancele el contexto.
func (m *Monitor) Run(ctx context.Context) {
	// Determinar qué fuentes están disponibles
	hasNM := m.nm != nil
	hasSDM := m.sdm != nil

	if hasNM {
		m.runNM(ctx)
	} else if hasSDM {
		m.runSDM(ctx)
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
		}
	}
}

// runSDM ejecuta el bucle usando systemd-networkd como fuente principal,
// con verificación HTTP de respaldo. Se suscribe a los cambios de estado del
// monitor systemd-networkd para reaccionar en tiempo real y usa el ticker
// solo como heartbeat periódico.
func (m *Monitor) runSDM(ctx context.Context) {
	// Arrancar el bucle interno de systemd-networkd (polling de interfaces y rutas).
	safe.Go("connectivity.systemd-networkd", func() { m.sdm.Run(m.interval) })

	// Suscribirse a los cambios de estado de systemd-networkd.
	ch := m.sdm.Subscribe()
	defer m.sdm.Unsubscribe(ch)

	// Verificación inicial inmediata.
	m.verifyAndSetState("sdm-init")

	ticker := time.NewTicker(m.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case sdmOnline := <-ch:
			if !sdmOnline {
				// systemd-networkd informa desconexión: offline inmediato.
				m.updateState(false, "systemd-networkd-down")
			} else {
				// systemd-networkd informa conexión: verificar internet por HTTP.
				m.verifyAndSetState("systemd-networkd-up")
			}
		case <-ticker.C:
			// Heartbeat periódico para detectar cambios en systemd-networkd.
			m.verifyAndSetState("heartbeat")
		}
	}
}

// runPolling ejecuta el bucle de comprobación periódica cuando ni NetworkManager
// ni systemd-networkd están disponibles.
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

	// Si systemd-networkd afirma estar desconectado, también marcar offline
	if m.sdm != nil && m.sdm.isDefinitelyOffline() {
		m.updateState(false, source+"(sdm-offline)")
		return
	}

	m.startCheck(source)
}

// startCheck lanza la comprobación HTTP en segundo plano.
func (m *Monitor) startCheck(source string) {
	m.checkMu.Lock()
	if m.checking {
		// Hay una comprobación en curso. Su resultado ya está obsoleto: la
		// decisión que acaba de llegar es más reciente, así que se invalida
		// (subiendo seq) y se repite la comprobación al terminar la actual.
		//
		// Sin invalidarla, se aplicaría un "offline" viejo y el cliente
		// vería un parpadeo offline→online al recuperar la red.
		m.pendingCheck = true
		m.pendingSrc = source
		m.seq++
		m.checkMu.Unlock()
		return
	}
	m.checking = true
	seq := m.seq
	m.checkMu.Unlock()

	safe.Go("connectivity.check", func() {
		// Restablecer la bandera incluso si la comprobación entra en panic:
		// si no, el monitor dejaría de comprobar la conexión para siempre.
		defer func() {
			m.checkMu.Lock()
			m.checking = false
			pending := m.pendingCheck
			pendSrc := m.pendingSrc
			m.pendingCheck = false
			m.pendingSrc = ""
			m.checkMu.Unlock()

			// Ha llegado un evento mientras comprobábamos: hay que volver a
			// comprobar para no perderlo.
			if pending {
				if pendSrc == "" {
					pendSrc = source
				}
				m.startCheck(pendSrc)
			}
		}()

		online := m.check()

		// Solo aplicar si no se ha tomado una decisión más reciente (por
		// ejemplo, un evento de NetworkManager o un ReportSuccess).
		m.updateStateIfCurrent(seq, online, source)
	})
}

// updateStateIfCurrent actualiza el estado solo si no se ha producido una
// decisión más reciente que la dada. Devuelve false si se descartó.
func (m *Monitor) updateStateIfCurrent(seq uint64, online bool, source string) bool {
	m.checkMu.Lock()
	if m.seq != seq {
		m.checkMu.Unlock()
		return false
	}
	m.seq++
	m.checkMu.Unlock()

	m.applyState(online, source)
	return true
}

// updateStateFromSDM actualiza el estado basándose en el monitor systemd-networkd.
// Devuelve true si el estado cambió.
func (m *Monitor) updateStateFromSDM(online bool, source string) bool {
	m.mu.Lock()
	prev := m.state
	state := StateOffline
	if online {
		state = StateOnline
	}
	m.state = state
	changed := state != prev
	m.mu.Unlock()

	if changed {
		logger.Info("conectividad", "prev", prev, "current", state, "fuente", source)
	}

	return changed
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
	// Invalida cualquier comprobación HTTP en vuelo: esta decisión es más
	// reciente que la que pudiera haber devuelto esa comprobación.
	m.checkMu.Lock()
	m.seq++
	m.checkMu.Unlock()

	m.applyState(online, source)
}

// applyState guarda el estado y avisa a los suscriptores si cambió.
func (m *Monitor) applyState(online bool, source string) {
	m.mu.Lock()
	prev := m.state
	state := StateOffline
	if online {
		state = StateOnline
	}
	m.state = state
	changed := state != prev
	subs := make([]chan State, 0, len(m.subs))
	for ch := range m.subs {
		subs = append(subs, ch)
	}
	m.mu.Unlock()

	if changed {
		logger.Info("conectividad", "prev", prev, "current", state, "fuente", source)
		for _, ch := range subs {
			select {
			case ch <- state:
			default:
				// Suscriptor lento: no bloquear el monitor.
			}
		}
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

// Source devuelve el mecanismo de red activo actualmente.
// Valores posibles: "networkmanager", "systemd-networkd", "http-polling"
func (m *Monitor) Source() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.source
}

// IsOnline devuelve true si el estado actual es online.
//
// Si el estado todavía es desconocido (el monitor acaba de arrancar y la
// primera comprobación sigue en curso) se asume que hay conexión: el
// proveedor de clima tiene sus propios tiempos de espera, y tratar la
// incertidumbre como "sin red" haría que la shell recibiera un error en la
// primera petición de clima en lugar de un parte real.
func (m *Monitor) IsOnline() bool {
	state := m.State()
	if state == StateUnknown {
		return true
	}
	return state == StateOnline
}

// Close cierra los recursos del monitor (conexión D-Bus si se usa NM,
// conexión systemd-networkd si se usa).
func (m *Monitor) Close() error {
	if m.nm != nil {
		if err := m.nm.Close(); err != nil {
			return err
		}
	}
	if m.sdm != nil {
		if err := m.sdm.Close(); err != nil {
			return err
		}
	}
	return nil
}

// compilo-check de interfaz.
var (
	_ interface{ Run(context.Context) }   = (*Monitor)(nil)
	_ interface{ Subscribe() chan State } = (*Monitor)(nil)
	_ interface{ Close() error }          = (*Monitor)(nil)
)
