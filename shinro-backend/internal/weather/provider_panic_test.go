package weather

import (
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

// panicTransport entra en panic en cada petición: simula un proveedor que
// devuelve algo inesperado (o un bug interno) y que antes tumbaba el daemon.
type panicTransport struct{}

func (panicTransport) RoundTrip(*http.Request) (*http.Response, error) {
	panic("fallo grave dentro del proveedor de clima")
}

// TestSnapshotSurvivesPanic comprueba que un panic durante la descarga del
// parte no se propaga: se convierte en un error que el cliente puede mostrar,
// y el proceso sigue vivo.
func TestSnapshotSurvivesPanic(t *testing.T) {
	w := New()
	w.SetHTTPTransport(panicTransport{})

	snap, err := w.Snapshot("Vigo", "es")
	if err == nil {
		t.Fatal("esperaba error tras el panic")
	}
	if snap.City != "" {
		t.Fatalf("esperaba snapshot vacío, got %+v", snap)
	}

	// El mapa de vuelos no debe crecer: si se quedara la entrada, el
	// proveedor acumularía basura con cada petición fallida.
	w.flightsMu.Lock()
	pending := len(w.flights)
	w.flightsMu.Unlock()
	if pending != 0 {
		t.Fatalf("esperaba 0 vuelos pendientes, got %d", pending)
	}
}

// TestSnapshotFollowersDoNotHang comprueba que las peticiones concurrentes de
// la misma ubicación no se quedan colgadas esperando a un líder que murió.
//
// Es el escenario más peligroso: un follower esperando en <-call.done que
// nunca se cierra deja una goroutine colgada para siempre (y, con ella, la
// memoria que sostiene).
func TestSnapshotFollowersDoNotHang(t *testing.T) {
	w := New()
	w.SetHTTPTransport(panicTransport{})

	const clients = 8
	var wg sync.WaitGroup
	errs := make(chan error, clients)

	for range clients {
		wg.Go(func() {
			_, err := w.Snapshot("Vigo", "es")
			errs <- err
		})
	}

	finished := make(chan struct{})
	go func() {
		wg.Wait()
		close(finished)
	}()

	select {
	case <-finished:
	case <-time.After(10 * time.Second):
		t.Fatal("timeout: alguna petición quedó colgada")
	}

	close(errs)
	for err := range errs {
		if err == nil {
			t.Fatal("esperaba error en todas las peticiones")
		}
	}
}

// TestSnapshotRecoversAfterPanic comprueba que el proveedor sigue funcionando
// después de un panic: un fallo puntual no deja al módulo inservible.
func TestSnapshotRecoversAfterPanic(t *testing.T) {
	w := New()
	w.SetHTTPTransport(panicTransport{})

	if _, err := w.Snapshot("Vigo", "es"); err == nil {
		t.Fatal("esperaba error con el transport que entra en panic")
	}

	// Restaurar un transport que funciona: el proveedor debe recuperarse.
	ts := &testServer{forecast: forecastJSON(21.0)}
	srv := httptest.NewServer(http.HandlerFunc(ts.handler))
	defer srv.Close()

	w.SetHTTPTransport(&redirectTransport{target: srv.URL})

	snap, err := w.Snapshot("Vigo", "es")
	if err != nil {
		t.Fatalf("esperaba éxito tras recuperarse del panic: %v", err)
	}
	if snap.Current.Temperature2M != 21.0 {
		t.Fatalf("esperaba 21.0, got %v", snap.Current.Temperature2M)
	}
}
