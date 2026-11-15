// Package socket: informe de salud del daemon y de sus módulos.
//
// El módulo "ping" no se limita a responder "ok": devuelve el estado real de
// cada módulo (último envío, errores, duración media), del daemon (uptime,
// goroutines, memoria, clientes) y una lista de problemas y sugerencias.
//
// Es la herramienta de diagnóstico del backend: sin ella, un módulo que falla
// en segundo plano es invisible (el log lo dice, pero nadie lo lee a diario).
package socket

import (
	"fmt"
	"math"
	"runtime"
	"sort"
	"time"
)

// Estado de un módulo en el informe de salud.
const (
	// ModuleStatusOK: el último envío del módulo fue correcto.
	ModuleStatusOK = "ok"
	// ModuleStatusError: el último envío del módulo falló.
	ModuleStatusError = "error"
	// ModuleStatusIdle: el módulo no ha enviado nada todavía (o no envía
	// nada de forma periódica).
	ModuleStatusIdle = "idle"
)

// Estado global del daemon.
const (
	HealthStatusOK       = "ok"       // todo en orden
	HealthStatusDegraded = "degraded" // algo va mal pero el daemon sirve
	HealthStatusError    = "error"    // algún módulo está fallando
)

// ModuleHealth es el estado de un módulo.
type ModuleHealth struct {
	// Name es el identificador del módulo ("system", "weather", ...).
	Name string `json:"name"`

	// Status: "ok", "error" o "idle".
	Status string `json:"status"`

	// Subscribed indica si el cliente que pregunta está suscrito a este
	// módulo.
	Subscribed bool `json:"subscribed"`

	// Subscribers es el número de clientes suscritos en total.
	Subscribers int `json:"subscribers"`

	// Interval es el intervalo periódico más corto configurado entre los
	// clientes suscritos (segundos; 0 = el módulo no hace envíos
	// periódicos, solo trabaja bajo demanda).
	Interval int `json:"interval"`

	// Sends y Errors son los contadores de envíos correctos y fallidos.
	Sends  int64 `json:"sends"`
	Errors int64 `json:"errors"`

	// LastSendMS son los milisegundos transcurridos desde el último envío
	// correcto (-1 si nunca ha enviado).
	LastSendMS int64 `json:"last_send_ms_ago"`

	// LastDurationMS y AvgDurationMS: cuánto tarda el módulo en responder.
	// Es el dato que dice qué módulo es el cuello de botella.
	LastDurationMS float64 `json:"last_duration_ms"`
	AvgDurationMS  float64 `json:"avg_duration_ms"`

	// LastError es el mensaje del último fallo y LastErrorMS cuánto lleva
	// sin ocurrir.
	LastError   string `json:"last_error,omitempty"`
	LastErrorMS int64  `json:"last_error_ms_ago,omitempty"`

	// Timings es el desglose del tiempo de respuesta del módulo (qué parte
	// del trabajo se lleva cada milisegundo). Solo lo rellenan los módulos
	// que saben descomponerlo.
	Timings map[string]float64 `json:"timings,omitempty"`
}

// ModuleTimings es implementado por los módulos que saben descomponer su
// tiempo de respuesta, para que el informe de salud diga en qué se va el
// tiempo y no solo cuánto tarda en total.
type ModuleTimings interface {
	Timings() map[string]float64
}

// Health es el informe de salud completo.
type Health struct {
	// OK se mantiene como string ("true") por compatibilidad con el payload
	// anterior del módulo ping. El estado real está en Status.
	OK string `json:"ok"`

	// Status: "ok", "degraded" o "error".
	Status string `json:"status"`

	// UptimeSeconds: cuánto lleva el daemon en marcha.
	UptimeSeconds float64 `json:"uptime_seconds"`

	// Goroutines: goroutines vivas ahora mismo.
	Goroutines int `json:"goroutines"`

	// GoroutinesDelta y MemoryDelta son las tendencias: cuántas goroutines y
	// cuántos MB han creescido en los últimos 5 minutos. Son la señal que
	// delata una fuga (un delta contra el arranque no valdría: el daemon
	// arranca módulos a medida que llegan clientes).
	GoroutinesDelta int     `json:"goroutines_delta_5m"`
	MemoryDelta     float64 `json:"memory_delta_5m"`

	// MemoryMB: memoria del heap en MB.
	MemoryMB float64 `json:"memory_mb"`

	// Clients: clientes conectados al socket.
	Clients int `json:"clients"`

	// Connectivity: "online", "offline" o "unknown".
	Connectivity string `json:"connectivity"`

	// Problems: cosas que están fallando ahora mismo.
	Problems []string `json:"problems"`

	// Suggestions: cosas que no están rotas pero se pueden mejorar.
	Suggestions []string `json:"suggestions"`

	// Modules: el estado de cada módulo registrado.
	Modules []ModuleHealth `json:"modules"`
}

// moduleStat son las estadísticas acumuladas de un módulo.
type moduleStat struct {
	sends     int64
	errors    int64
	lastSend  time.Time
	lastDur   time.Duration
	totalDur  time.Duration
	lastErr   string
	lastErrAt time.Time
}

// recordModuleResult anota el resultado de una operación de un módulo.
//
// err nil cuenta como un envío correcto; si no, cuenta como un error y se
// guarda el mensaje para poder diagnostics.
func (s *Server) recordModuleResult(name string, err error, dur time.Duration) {
	if s == nil || name == "" {
		return
	}
	s.statsMu.Lock()
	defer s.statsMu.Unlock()
	if s.stats == nil {
		s.stats = make(map[string]*moduleStat)
	}
	st := s.stats[name]
	if st == nil {
		st = &moduleStat{}
		s.stats[name] = st
	}
	if err != nil {
		st.errors++
		st.lastErr = err.Error()
		st.lastErrAt = time.Now()
		return
	}
	st.sends++
	st.lastSend = time.Now()
	st.lastDur = dur
	st.totalDur += dur
}

// snapshotStats devuelve una copia de las estadísticas por módulo.
func (s *Server) snapshotStats() map[string]moduleStat {
	s.statsMu.Lock()
	defer s.statsMu.Unlock()
	out := make(map[string]moduleStat, len(s.stats))
	for k, v := range s.stats {
		out[k] = *v
	}
	return out
}

// snapshotHealth construye el informe de salud.
//
// c es el cliente que pregunta: sirve para saber a qué módulos está
// suscrito ese cliente en concreto (puede ser nil).
func (s *Server) snapshotHealth(c *client) Health {
	now := time.Now()

	h := Health{
		OK:            "true",
		Status:        HealthStatusOK,
		UptimeSeconds: now.Sub(s.startedAt).Seconds(),
		Goroutines:    runtime.NumGoroutine(),
		Connectivity:  "unknown",
		Problems:      []string{},
		Suggestions:   []string{},
		Modules:       []ModuleHealth{},
	}
	// Tendencia de los últimos 5 minutos: si el daemon lleva menos tiempo
	// que eso en marcha, no hay con qué comparar y no se informa de fugas.
	if dG, dM, ok := s.history.delta(now, 5*time.Minute); ok {
		h.GoroutinesDelta = dG
		h.MemoryDelta = dM
	}

	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	h.MemoryMB = float64(ms.HeapAlloc) / (1024 * 1024)

	s.mu.Lock()
	clients := make([]*client, 0, len(s.clients))
	for cl := range s.clients {
		clients = append(clients, cl)
	}
	s.mu.Unlock()
	h.Clients = len(clients)

	if s.connMon != nil {
		h.Connectivity = s.connMon.State().String()
	}

	stats := s.snapshotStats()

	for _, name := range s.registry.Names() {
		m := s.registry.Get(name)
		if m == nil {
			continue
		}
		mh := ModuleHealth{
			Name:        name,
			Status:      ModuleStatusIdle,
			LastSendMS:  -1,
			LastErrorMS: -1,
		}
		if c != nil {
			mh.Subscribed = c.isSubscribed(name)
		}
		// El intervalo relevante es el de los clientes suscritos (el más
		// corto): es cada cuánto debería llegar el siguiente envío. El
		// intervalo del cliente que pregunta solo vale si está suscrito.
		for _, cl := range clients {
			if !cl.isSubscribed(name) {
				continue
			}
			mh.Subscribers++
			iv := cl.modInterval(name)
			if iv > 0 && (mh.Interval == 0 || iv < mh.Interval) {
				mh.Interval = iv
			}
		}

		if st, ok := stats[name]; ok {
			mh.Sends = st.sends
			mh.Errors = st.errors
			mh.LastError = st.lastErr
			if !st.lastSend.IsZero() {
				mh.LastSendMS = now.Sub(st.lastSend).Milliseconds()
				mh.LastDurationMS = roundMS(float64(st.lastDur.Microseconds()) / 1000)
				if st.sends > 0 {
					mh.AvgDurationMS = roundMS(float64(st.totalDur.Microseconds()) / 1000 / float64(st.sends))
				}
				mh.Status = ModuleStatusOK
			}
			if !st.lastErrAt.IsZero() {
				mh.LastErrorMS = now.Sub(st.lastErrAt).Milliseconds()
				// El último error manda si fue más reciente que el último
				// envío correcto: el módulo está fallando ahora mismo.
				if st.lastErrAt.After(st.lastSend) {
					mh.Status = ModuleStatusError
				}
			}
		}

		// Desglose del tiempo de respuesta, si el módulo lo sabe.
		if mt, ok := m.(ModuleTimings); ok {
			if timings := mt.Timings(); len(timings) > 0 {
				mh.Timings = timings
			}
		}

		h.Modules = append(h.Modules, mh)
	}

	// El módulo ping es el que genera este informe: está respondiendo ahora
	// mismo, así que no puede estar "idle" aunque su contador vaya un paso
	// por detrás (el servidor lo anota después de responder).
	for i := range h.Modules {
		if h.Modules[i].Name == "ping" && h.Modules[i].Status == ModuleStatusIdle {
			h.Modules[i].Status = ModuleStatusOK
		}
	}

	h.Problems, h.Suggestions = evaluateHealth(&h)
	if h.Status == HealthStatusOK {
		h.OK = "true"
	}
	return h
}

// evaluateHealth deduce los problemas y las sugerencias a partir del informe.
//
// Problems: algo está roto o atascado AHORA MISMO. Cada problema apunta a un
// fallo concreto (un módulo que falla, un pump muerto, una fuga).
//
// Suggestions: nada está roto, pero el dato apunta a una mejora concreta
// (un cuello de botella, un consumo anómalo).
//
// Lo que NO se reporta: que un módulo no tenga clientes suscritos. Eso no es
// un problema: los módulos bajo demanda (files, clipboard) solo trabajan
// cuando hace falta, y un módulo periódico sin suscriptores simplemente no
// está pumping. Reportarlo sería ruido que esconde los problemas de verdad.
func evaluateHealth(h *Health) (problems []string, suggestions []string) {
	problems = []string{}
	suggestions = []string{}

	// Sin conexión, los errores de los módulos que necesitan Internet no
	// son fallos del módulo: son consecuencia de no tener red.
	notaSinRed := ""
	if h.Connectivity == "offline" {
		notaSinRed = " (sin conexión a Internet: puede ser la causa)"
	}

	for _, m := range h.Modules {
		// 1. El último intento del módulo falló.
		if m.Status == ModuleStatusError {
			problems = append(problems, fmt.Sprintf(
				"%s: último error hace %s: %s%s",
				m.Name, humanDurationMS(m.LastErrorMS), m.LastError, notaSinRed))
			h.Status = HealthStatusError
			continue
		}

		// 2. Módulo periódico que no está enviando: el pump está muerto o
		//    colgado.
		//
		//    Solo aplica a los módulos con intervalo configurado. Los que
		//    trabajan bajo demanda (files, clipboard) no tienen por qué
		//    enviar nada hasta que pase algo.
		if m.Interval <= 0 || m.Subscribers == 0 {
			continue
		}
		switch {
		case m.Sends == 0 && m.Errors == 0:
			problems = append(problems, fmt.Sprintf(
				"%s: suscrito por %d cliente(s) con intervalo de %d s, pero no ha enviado nada",
				m.Name, m.Subscribers, m.Interval))
			if h.Status == HealthStatusOK {
				h.Status = HealthStatusDegraded
			}
		case m.LastSendMS >= 0 && m.LastSendMS > int64(m.Interval)*3*1000:
			problems = append(problems, fmt.Sprintf(
				"%s: sin enviar desde %s, con intervalo de %d s: el pump puede estar colgado",
				m.Name, humanDurationMS(m.LastSendMS), m.Interval))
			if h.Status == HealthStatusOK {
				h.Status = HealthStatusDegraded
			}
		}
	}

	// El cuello de botella: qué módulo tarda más.
	//
	// Se mira la última medición y no la media: la media la domina el
	// arranque en frío (la primera petición sí va a la red) y el resto de
	// las pueden servir desde caché.
	var lento *ModuleHealth
	for i := range h.Modules {
		m := &h.Modules[i]
		if m.LastDurationMS <= 0 {
			continue
		}
		if lento == nil || m.LastDurationMS > lento.LastDurationMS {
			lento = m
		}
	}
	if lento != nil {
		switch {
		case lento.LastDurationMS >= 1000:
			suggestions = append(suggestions, fmt.Sprintf(
				"%s tarda %.0f ms: es el cuello de botella del refresco",
				lento.Name, lento.LastDurationMS))
		case lento.LastDurationMS >= 100:
			suggestions = append(suggestions, fmt.Sprintf(
				"%s tarda %.0f ms: si se refresca a menudo, conviene cachear",
				lento.Name, lento.LastDurationMS))
		}
	}

	// Fugas: lo que ha crecido en los últimos 5 minutos.
	//
	// El umbral es alto a propósito: entre consultas pueden abrirse y
	// cerrarse clientes, y eso mueve el número de goroutines. Lo que delata
	// una fuga es un crecimiento sostenido.
	if h.GoroutinesDelta > 10 {
		suggestions = append(suggestions, fmt.Sprintf(
			"%+d goroutines en los últimos 5 min: posible fuga", h.GoroutinesDelta))
	}
	if h.MemoryDelta > 20 {
		suggestions = append(suggestions, fmt.Sprintf(
			"%.0f MB de heap más en los últimos 5 min: posible fuga", h.MemoryDelta))
	}

	sort.Strings(problems)
	return problems, suggestions
}

// roundMS redondea una duración en milisegundos a dos decimales, para que el
// informe no muestre decimales innecesarios.
func roundMS(ms float64) float64 {
	return math.Round(ms*100) / 100
}

// humanDurationMS formatea una duración en milisegundos de forma legible.
func humanDurationMS(ms int64) string {
	switch {
	case ms < 0:
		return "?"
	case ms < 1000:
		return fmt.Sprintf("%d ms", ms)
	case ms < 60*1000:
		return fmt.Sprintf("%.1f s", float64(ms)/1000)
	case ms < 3600*1000:
		return fmt.Sprintf("%d min", ms/(60*1000))
	default:
		return fmt.Sprintf("%.1f h", float64(ms)/(3600*1000))
	}
}
