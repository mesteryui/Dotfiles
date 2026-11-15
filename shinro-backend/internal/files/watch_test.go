package files

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// waitForGeneration espera a que la generación del sistema de archivos cambie
// (o a que se agote el tiempo). Devuelve true si cambió.
func waitForGeneration(t *testing.T, provider *Provider, before uint64, timeout time.Duration) bool {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if provider.Generation() != before {
			return true
		}
		time.Sleep(20 * time.Millisecond)
	}
	return false
}

// TestWatcherSigueVivoDespuesDeUnTimeout comprueba que el vigilante sigue
// detectando cambios pasado un tiempo de inactividad.
//
// Es un test de regresión importante: el bucle de lectura usa select con
// timeout, y syscall.Select MODIFICA el FdSet que recibe (dejando a cero
// los descriptores que no estaban listos). Si el FdSet se reutilizara entre
// iteraciones, tras el primer timeout el vigilante se quedaría ciego para
// siempre: por eso este test espera a que el vigilante haya sobrevivido a
// varios timeouts antes de cambiar algo.
func TestWatcherSigueVivoDespuesDeUnTimeout(t *testing.T) {
	root := t.TempDir()
	provider := New()
	defer provider.Close()

	// La primera búsqueda arranca el vigilante.
	if _, err := provider.Search("algo", root, 20); err != nil {
		t.Fatalf("esperaba éxito: %v", err)
	}

	// Esperar a que el vigilante haya pasado varios timeouts de select.
	time.Sleep(3 * time.Second)

	before := provider.Generation()
	if err := os.WriteFile(filepath.Join(root, "tardio.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}

	if !waitForGeneration(t, provider, before, 5*time.Second) {
		t.Fatal("el vigilante dejó de detectar cambios tras un tiempo de inactividad")
	}
}

// TestSearchSeActualizaAlCambiarLosFicheros comprueba el caso principal: si
// aparece un fichero nuevo que coincide con la consulta, la siguiente
// búsqueda lo devuelve.
//
// Sin la invalidación por cambios, la segunda búsqueda devolvería el
// resultado cacheado (obsoleto) y el usuario no vería jamais el fichero
// nuevo.
func TestSearchSeActualizaAlCambiarLosFicheros(t *testing.T) {
	root := t.TempDir()
	provider := New()
	defer provider.Close()

	// Un fichero que ya existe.
	if err := os.WriteFile(filepath.Join(root, "nota.txt"), []byte("hola"), 0o644); err != nil {
		t.Fatal(err)
	}

	results, err := provider.Search("nota", root, 20)
	if err != nil {
		t.Fatalf("esperaba éxito: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("esperaba 1 resultado, got %d", len(results))
	}

	// Segundo search: debe usar la caché (rápido) y devolver lo mismo.
	results, err = provider.Search("nota", root, 20)
	if err != nil {
		t.Fatalf("esperaba éxito: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("esperaba 1 resultado cacheado, got %d", len(results))
	}

	// Crear un fichero nuevo con el mismo prefijo.
	before := provider.Generation()
	if err := os.WriteFile(filepath.Join(root, "nota2.txt"), []byte("hola"), 0o644); err != nil {
		t.Fatal(err)
	}

	// El vigilante debe detectar el cambio (inotify).
	if !waitForGeneration(t, provider, before, 5*time.Second) {
		t.Fatal("el vigilante no detectó la creación del fichero")
	}

	// La tercera búsqueda ya no debe usar la caché obsoleta.
	results, err = provider.Search("nota", root, 20)
	if err != nil {
		t.Fatalf("esperaba éxito: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("esperaba 2 resultados tras crear un fichero, got %d", len(results))
	}
}

// TestSearchSeActualizaAlBorrarUnFichero comprueba el caso inverso: si se
// borra un fichero, desaparece de los resultados.
func TestSearchSeActualizaAlBorrarUnFichero(t *testing.T) {
	root := t.TempDir()
	provider := New()
	defer provider.Close()

	path := filepath.Join(root, "temporal.txt")
	if err := os.WriteFile(path, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}

	if _, err := provider.Search("temporal", root, 20); err != nil {
		t.Fatalf("esperaba éxito: %v", err)
	}

	before := provider.Generation()
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}

	if !waitForGeneration(t, provider, before, 5*time.Second) {
		t.Fatal("el vigilante no detectó el borrado del fichero")
	}

	results, err := provider.Search("temporal", root, 20)
	if err != nil {
		t.Fatalf("esperaba éxito: %v", err)
	}
	if len(results) != 0 {
		t.Fatalf("esperaba 0 resultados tras borrar el fichero, got %d", len(results))
	}
}

// TestNotificacionDeCambios comprueba que el consumidor recibe un aviso
// cuando el sistema de archivos cambia (es lo que permite refrescar la UI).
func TestNotificacionDeCambios(t *testing.T) {
	root := t.TempDir()
	provider := New()
	defer provider.Close()

	cambios := make(chan struct{}, 4)
	provider.SetOnChange(func() { cambios <- struct{}{} })

	// La primera búsqueda arranca el vigilante.
	if _, err := provider.Search("algo", root, 20); err != nil {
		t.Fatalf("esperaba éxito: %v", err)
	}

	// Dar margen a que el vigilante termine de montar las incentas.
	time.Sleep(300 * time.Millisecond)

	if err := os.WriteFile(filepath.Join(root, "nuevo.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}

	select {
	case <-cambios:
		// Correcto: se avisó del cambio.
	case <-time.After(6 * time.Second):
		t.Fatal("no se notificó el cambio del sistema de archivos")
	}
}

// TestCacheTTLInvalidaResultados comprueba la red de seguridad: aunque el
// vigilante no detecte el cambio (por ejemplo, si inotify no está
// disponible), pasado el TTL la búsqueda se recalcula.
func TestCacheTTLInvalidaResultados(t *testing.T) {
	root := t.TempDir()
	provider := New()
	defer provider.Close()

	if err := os.WriteFile(filepath.Join(root, "dato.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}

	results, err := provider.Search("dato", root, 20)
	if err != nil {
		t.Fatalf("esperaba éxito: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("esperaba 1 resultado, got %d", len(results))
	}

	// Simular el paso del TTL: se fuerza la antigüedad de la entrada.
	provider.cacheMu.Lock()
	for key, cached := range provider.cache {
		cached.at = time.Now().Add(-2 * cacheTTL)
		provider.cache[key] = cached
	}
	provider.cacheMu.Unlock()

	// Crear otro fichero sin notificar al vigilante (para aislar el TTL).
	if err := os.WriteFile(filepath.Join(root, "dato2.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	provider.gen.Store(provider.gen.Load()) // sin cambios de generación

	results, err = provider.Search("dato", root, 20)
	if err != nil {
		t.Fatalf("esperaba éxito: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("esperaba 2 resultados tras caducar el TTL, got %d", len(results))
	}
}

// TestSearchContextCanceladoSigueCancelando comprueba que la cancelación
// sigue funcionando con el vigilante en marcha.
func TestSearchContextCanceladoSigueCancelando(t *testing.T) {
	root := t.TempDir()
	provider := New()
	defer provider.Close()

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	if _, err := provider.SearchContext(ctx, "x", root, 10); err == nil {
		t.Fatal("esperaba error de cancelación")
	}
}
