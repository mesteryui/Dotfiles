package connectivity

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"sync/atomic"
	"testing"
	"time"
)

// TestEventoNoSePierdeDuranteUnaComprobacion comprueba que un evento que
// llega mientras hay una comprobación HTTP en curso no se pierde.
//
// El caso real: la red vuelve justo cuando una comprobación HTTP (iniciada
// con la red todavía caída) sigue en marcha. Con el comportamiento anterior,
// ese evento se descartaba y el estado se quedaba en "offline" hasta el
// siguiente heartbeat (hasta 30 s más tarde).
func TestEventoNoSePierdeDuranteUnaComprobacion(t *testing.T) {
	os.Setenv("SHINRO_CONNECTIVITY_DISABLE_NM", "1")
	defer os.Unsetenv("SHINRO_CONNECTIVITY_DISABLE_NM")

	var online atomic.Int32
	var comprobaciones int32

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// El estado se decide al empezar la petición: así una comprobación
		// que arrancó con la red caída devuelve "offline" aunque la red
		// vuelva mientras espera.
		estado := online.Load()
		atomic.AddInt32(&comprobaciones, 1)
		// Tardar lo suficiente para que el evento llegue durante el vuelo.
		time.Sleep(300 * time.Millisecond)
		if estado == 1 {
			w.WriteHeader(http.StatusOK)
		} else {
			w.WriteHeader(http.StatusServiceUnavailable)
		}
	}))
	defer srv.Close()

	m := New(srv.URL, 10*time.Second)
	ch := m.Subscribe()
	defer m.Unsubscribe(ch)

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	go m.Run(ctx)

	// La comprobación inicial está en vuelo cuando llega la recuperación.
	time.Sleep(50 * time.Millisecond)
	online.Store(1)
	m.verifyAndSetState("test-recuperacion")

	// Debe terminar online: el evento no puede perderse aunque la
	// comprobación en vuelo devolviera "offline".
	deadline := time.Now().Add(8 * time.Second)
	for time.Now().Before(deadline) {
		select {
		case st := <-ch:
			if st == StateOnline {
				// Además tiene que haber habido una comprobación nueva: la
				// que estaba en vuelo no vio la red recuperada.
				if atomic.LoadInt32(&comprobaciones) < 2 {
					t.Fatalf("esperaba una comprobación nueva tras el evento, hubo %d", comprobaciones)
				}
				return
			}
		case <-time.After(50 * time.Millisecond):
		}
	}
	t.Fatal("el evento de recuperación de red se perdió: el estado se quedó en offline")
}
