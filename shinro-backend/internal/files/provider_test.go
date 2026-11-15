package files

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

// makeTree crea un árbol de directorios con algunos archivos.
func makeTree(t *testing.T) string {
	t.Helper()
	root := t.TempDir()

	for _, dir := range []string{"docs", "src", "imgs"} {
		if err := os.MkdirAll(filepath.Join(root, dir), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	files := []string{
		"docs/informe.pdf",
		"docs/notas.txt",
		"src/main.go",
		"src/util.go",
		"imgs/foto.png",
	}
	for _, f := range files {
		if err := os.WriteFile(filepath.Join(root, f), []byte("datos"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

func TestSearchContextCancelado(t *testing.T) {
	root := makeTree(t)
	provider := New()

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err := provider.SearchContext(ctx, "informe", root, 10)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("esperaba context.Canceled, got %v", err)
	}
}

// TestSearchCanceladoNoEnvenenaCache comprueba que una búsqueda cancelada no
// deja un resultado vacío en la caché: la siguiente búsqueda debe encontrar
// los archivos de verdad.
func TestSearchCanceladoNoEnvenenaCache(t *testing.T) {
	root := makeTree(t)
	provider := New()

	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, _ = provider.SearchContext(ctx, "informe", root, 10)

	results, err := provider.Search("informe", root, 10)
	if err != nil {
		t.Fatalf("esperaba éxito, got %v", err)
	}
	if len(results) == 0 {
		t.Fatal("esperaba resultados: la búsqueda cancelada envenenó la caché")
	}
}

func TestSearchContextEncuentraArchivos(t *testing.T) {
	root := makeTree(t)
	provider := New()

	results, err := provider.SearchContext(context.Background(), "informe", root, 10)
	if err != nil {
		t.Fatalf("esperaba éxito, got %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("esperaba 1 resultado, got %d", len(results))
	}
	if results[0].Name != "informe.pdf" {
		t.Fatalf("esperaba informe.pdf, got %s", results[0].Name)
	}
}
