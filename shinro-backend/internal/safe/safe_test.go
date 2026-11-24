package safe

import (
	"strings"
	"sync"
	"testing"
)

// TestGoRecoversPanic comprueba que un panic en una goroutine protegida no
// tumba el proceso: es el requisito básico para que el daemon sobreviva a un
// fallo puntual en cualquier módulo.
func TestGoRecoversPanic(t *testing.T) {
	done := make(chan struct{})

	Go("test.panic", func() {
		defer close(done)
		panic("boom")
	})

	<-done

	// Si el panic no se hubiera recuperado, el proceso habría muerto aquí.
	// reaching this point means the daemon would still be alive.
	if !strings.Contains("ok", "ok") {
		t.Fatal("nunca llega aquí")
	}
}

// TestDoConvertsPanicToError comprueba que safe.Do devuelve un error en vez
// de propagar el panic.
func TestDoConvertsPanicToError(t *testing.T) {
	err := Do("test.panic", func() error {
		panic("boom")
	})
	if err == nil {
		t.Fatal("esperaba error tras el panic")
	}
	if !strings.Contains(err.Error(), "boom") {
		t.Fatalf("el error no menciona el panic: %v", err)
	}
}

// TestDoPropagatesNormalError comprueba que safe.Do no interfiere con los
// errores normales.
func TestDoPropagatesNormalError(t *testing.T) {
	sentinel := errSentinel{}
	err := Do("test.error", func() error { return sentinel })
	if err != sentinel {
		t.Fatalf("esperaba el error original, got %v", err)
	}
}

// TestDoValueReturnsZeroOnPanic comprueba que safe.DoValue devuelve el valor
// cero y un error si la función entra en panic.
func TestDoValueReturnsZeroOnPanic(t *testing.T) {
	value, err := DoValue("test.panic", func() (int, error) {
		panic("boom")
	})
	if err == nil {
		t.Fatal("esperaba error tras el panic")
	}
	if value != 0 {
		t.Fatalf("esperaba el valor cero, got %d", value)
	}
}

// TestDoValueReturnsValue comprueba el camino feliz.
func TestDoValueReturnsValue(t *testing.T) {
	value, err := DoValue("test.ok", func() (int, error) { return 42, nil })
	if err != nil {
		t.Fatalf("esperaba éxito, got %v", err)
	}
	if value != 42 {
		t.Fatalf("esperaba 42, got %d", value)
	}
}

// TestGuardSurvivesPanic comprueba que un bucle protegido con Guard sigue
// vivo tras un panic: el watcher del portapapeles debe reintentar, no morir.
func TestGuardSurvivesPanic(t *testing.T) {
	attempts := 0
	var mu sync.Mutex

	for range 3 {
		ok := Guard("test.guard", func() {
			mu.Lock()
			attempts++
			mu.Unlock()
			panic("boom")
		})
		if ok {
			t.Fatal("esperaba que Guard reportara el panic")
		}
	}

	mu.Lock()
	defer mu.Unlock()
	if attempts != 3 {
		t.Fatalf("esperaba 3 intentos, got %d", attempts)
	}
}

type errSentinel struct{}

func (errSentinel) Error() string { return "sentinel" }
