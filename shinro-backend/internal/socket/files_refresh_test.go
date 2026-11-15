package socket

import (
	"context"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"shinro-backend/internal/files"
)

// TestFilesSeRefrescaAlCambiarElSistemaDeArchivos comprueba el flujo
// completo: el cliente pide una búsqueda, se modifican los ficheros y el
// backend le empuja el resultado actualizado sin que vuelva a preguntar.
//
// Es el comportamiento que evita que la lista de ficheros de la UI se
// quede congelada con lo que había al abrir el lanzador.
func TestFilesSeRefrescaAlCambiarElSistemaDeArchivos(t *testing.T) {
	// Directorio de trabajo como raíz de la búsqueda.
	workDir := t.TempDir()
	t.Setenv("HOME", workDir)

	if err := os.WriteFile(filepath.Join(workDir, "nota.txt"), []byte("hola"), 0o644); err != nil {
		t.Fatal(err)
	}

	tmpDir := t.TempDir()
	socketPath := filepath.Join(tmpDir, "shinro")
	t.Setenv("SHINRO_SOCKET_PATH", socketPath)

	provider := files.New()
	defer provider.Close()
	registry := NewRegistry()
	registry.Register(NewFilesModule(provider))

	srv := NewServer(registry, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	errCh := make(chan error, 1)
	go func() { errCh <- srv.Start(ctx) }()

	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(socketPath); err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("no se pudo conectar al socket: %v", err)
	}
	defer conn.Close()

	hello := map[string]interface{}{
		"type":      "hello",
		"intervals": map[string]int{"files": 0},
	}
	helloBytes, _ := json.Marshal(hello)
	if _, err := conn.Write(append(helloBytes, '\n')); err != nil {
		t.Fatalf("error enviando hello: %v", err)
	}

	// Pedir la búsqueda.
	search := map[string]interface{}{
		"type":   "get",
		"module": "files",
		"action": "search",
		"query":  "nota",
		"limit":  20,
	}
	searchBytes, _ := json.Marshal(search)
	if _, err := conn.Write(append(searchBytes, '\n')); err != nil {
		t.Fatalf("error enviando search: %v", err)
	}

	// Leer la primera respuesta de búsqueda: debe traer 1 resultado.
	// (Antes puede llegar la respuesta de "hello".)
	results := readFilesResults(t, conn, 10*time.Second)
	if len(results) != 1 {
		t.Fatalf("esperaba 1 resultado inicial, got %d", len(results))
	}

	// Crear un fichero nuevo: el backend debe empujar el refresco solo.
	if err := os.WriteFile(filepath.Join(workDir, "nota2.txt"), []byte("hola"), 0o644); err != nil {
		t.Fatal(err)
	}

	deadline = time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		results = readFilesResults(t, conn, 5*time.Second)
		if len(results) == 2 {
			cancel()
			select {
			case <-errCh:
			case <-time.After(5 * time.Second):
				t.Fatal("timeout esperando a que se detuviera el servidor")
			}
			return
		}
	}

	t.Fatal("el backend no empujó la búsqueda actualizada tras cambiar el sistema de archivos")
}

// readFilesResults lee mensajes hasta encontrar una actualización del módulo
// files y devuelve sus resultados.
func readFilesResults(t *testing.T, conn net.Conn, timeout time.Duration) []interface{} {
	t.Helper()

	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		line, err := readLine(conn, time.Until(deadline))
		if err != nil {
			return nil
		}
		var msg map[string]interface{}
		if err := json.Unmarshal([]byte(line), &msg); err != nil {
			continue
		}
		if msg["module"] != "files" {
			continue
		}
		data, ok := msg["data"].(map[string]interface{})
		if !ok {
			continue
		}
		results, _ := data["results"].([]interface{})
		return results
	}
	return nil
}
