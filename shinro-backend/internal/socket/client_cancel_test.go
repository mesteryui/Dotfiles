package socket

import (
	"context"
	"testing"
	"time"
)

// TestCancelInFlightGeneric comprueba el mecanismo genérico de cancelación
// del cliente: un módulo registra su operación en vuelo y puede abortarla
// (o el servidor la aborta al cerrarse la conexión) sin que el socket sepa
// nada del módulo en concreto.
func TestCancelInFlightGeneric(t *testing.T) {
	c := &client{done: make(chan struct{})}

	ctx, cancel := context.WithCancel(context.Background())
	c.setCancelInFlight("demo", cancel)

	// Nada se cancela solo por registrar la operación.
	select {
	case <-ctx.Done():
		t.Fatal("la operación se canceló antes de tiempo")
	case <-time.After(50 * time.Millisecond):
	}

	// Una petición nueva del mismo tipo aborta la anterior.
	c.cancelInFlight("demo")
	select {
	case <-ctx.Done():
	case <-time.After(time.Second):
		t.Fatal("esperaba que cancelInFlight abortara la operación")
	}

	// Cancelar dos veces no debe entrar en panic.
	c.cancelInFlight("demo")
}

// TestCancelAllInFlightOnClose comprueba que al cerrarse la conexión se
// abortan todas las operaciones en vuelo del cliente: si no, sus goroutines
// seguirían trabajando sin poder entregar nada.
func TestCancelAllInFlightOnClose(t *testing.T) {
	c := &client{done: make(chan struct{})}

	ctxA, cancelA := context.WithCancel(context.Background())
	ctxB, cancelB := context.WithCancel(context.Background())
	c.setCancelInFlight("files", cancelA)
	c.setCancelInFlight("otro", cancelB)

	c.close()

	for name, ctx := range map[string]context.Context{"files": ctxA, "otro": ctxB} {
		select {
		case <-ctx.Done():
		case <-time.After(time.Second):
			t.Fatalf("esperaba que la operación %q se cancelara al cerrar el cliente", name)
		}
	}
}

// TestSetCancelInFlightReemplazaLaAnterior comprueba que registrar una
// operación nueva con la misma clave aborta la anterior: así no pueden
// coexistir dos operaciones del mismo tipo en vuelo.
func TestSetCancelInFlightReemplazaLaAnterior(t *testing.T) {
	c := &client{done: make(chan struct{})}

	ctxOld, cancelOld := context.WithCancel(context.Background())
	c.setCancelInFlight("files", cancelOld)

	ctxNew, cancelNew := context.WithCancel(context.Background())
	c.setCancelInFlight("files", cancelNew)

	select {
	case <-ctxOld.Done():
	case <-time.After(time.Second):
		t.Fatal("esperaba que la operación anterior se cancelara")
	}

	select {
	case <-ctxNew.Done():
		t.Fatal("la operación nueva no debe cancelarse")
	case <-time.After(50 * time.Millisecond):
	}
}
