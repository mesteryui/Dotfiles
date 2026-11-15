package socket

import (
	"context"
	"runtime"
	"sync"
	"time"

	"shinro-backend/internal/logger"
	"shinro-backend/internal/safe"
)

// Intervalo entre muestras del historial de salud.
const healthSampleInterval = 30 * time.Second

// healthSampleMax es cuántas muestras se guardan (2 horas a 30 s).
const healthSampleMax = 240

// healthSample es una medición del estado del daemon en un instante.
type healthSample struct {
	at         time.Time
	goroutines int
	memoryMB   float64
}

// healthHistory guarda las últimas mediciones del daemon.
//
// Sirve para distinguir una fuga de un simple transitorio de arranque: una
// comparación contra el arranque no sirve (el daemon arranca módulos a
// medida que llegan clientes), pero la TENDENCIA sí: si el número de
// goroutines o la memoria crecen sin parar, hay una fuga; si se estabilizan,
// no la hay.
type healthHistory struct {
	mu      sync.Mutex
	samples []healthSample
}

func newHealthHistory() *healthHistory {
	return &healthHistory{samples: make([]healthSample, 0, healthSampleMax)}
}

// add registra una medición y descarta la más antigua si hay demasiadas.
func (h *healthHistory) add(s healthSample) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.samples = append(h.samples, s)
	if len(h.samples) > healthSampleMax {
		h.samples = h.samples[len(h.samples)-healthSampleMax:]
	}
}

// latest devuelve la última medición.
func (h *healthHistory) latest() (healthSample, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(h.samples) == 0 {
		return healthSample{}, false
	}
	return h.samples[len(h.samples)-1], true
}

// delta devuelve la diferencia con la medición más reciente que sea al menos
// de age antigüedad.
//
// Si el daemon lleva menos tiempo que eso en marcha, no hay nada con qué
// comparar: se devuelve false y el informe no habla de fugas (un delta
// contra el arranque daría un falso positivo en cada arranque).
func (h *healthHistory) delta(now time.Time, age time.Duration) (int, float64, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if len(h.samples) < 2 {
		return 0, 0, false
	}
	objetivo := now.Add(-age)

	// La medición más reciente que sea al menos tan antigua como el objetivo.
	var base *healthSample
	for i := range h.samples {
		if !h.samples[i].at.After(objetivo) {
			base = &h.samples[i]
		}
	}
	if base == nil {
		return 0, 0, false
	}

	actual := h.samples[len(h.samples)-1]
	return actual.goroutines - base.goroutines, actual.memoryMB - base.memoryMB, true
}

// startHealthSampler muestrea el estado del daemon periódicamente.
//
// Las muestras alimentan el informe de salud: permiten ver si el consumo
// crece (fuga) o se estabiliza.
func (s *Server) startHealthSampler(ctx context.Context) {
	safe.Go("socket.health", func() {
		ticker := time.NewTicker(healthSampleInterval)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				s.history.add(s.sampleNow())
				s.logHealth()
			}
		}
	})
}

// sampleNow toma una medición del estado del daemon.
func (s *Server) sampleNow() healthSample {
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	return healthSample{
		at:         time.Now(),
		goroutines: runtime.NumGoroutine(),
		memoryMB:   float64(ms.HeapAlloc) / (1024 * 1024),
	}
}

// logHealth deja una línea en el log cuando el consumo crece de forma
// sostenida: es la señal que delata una fuga sin tener que consultar el ping.
//
// Solo se registra cuando hay un crecimiento claro, y como mucho una vez
// cada 5 minutos, para no llenar el journal con líneas rutinarias.
func (s *Server) logHealth() {
	deltaG, deltaM, ok := s.history.delta(time.Now(), 5*time.Minute)
	if !ok {
		return
	}
	if deltaG <= 10 && deltaM <= 20 {
		return
	}

	s.healthLogMu.Lock()
	ultimo := s.lastHealthLog
	ahora := time.Now()
	if !ultimo.IsZero() && ahora.Sub(ultimo) < 5*time.Minute {
		s.healthLogMu.Unlock()
		return
	}
	s.lastHealthLog = ahora
	s.healthLogMu.Unlock()

	logger.Info("salud del daemon",
		"goroutines_5m", deltaG,
		"memoria_mb_5m", roundMS(deltaM),
	)
}
