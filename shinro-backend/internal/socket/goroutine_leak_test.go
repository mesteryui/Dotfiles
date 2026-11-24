package socket

import (
	"context"
	"encoding/json"
	"net"
	"os"
	"runtime"
	"testing"
	"time"

	"shinro-backend/internal/system"
	"shinro-backend/internal/weather"
)

func systemProviderForTest() *system.Provider   { return system.New() }
func weatherProviderForTest() *weather.Provider { return weather.New() }

// TestServerNoDejaGoroutinesColgadas comprueba que el servidor no acumula
// goroutines: cada conexión que se abre y se cierra debe liberar las suyas.
//
// Es el test que protege contra fugas silenciosas que, tras días de uso
// continuo, acaban con el daemon devorando memoria.
func TestServerNoDejaGoroutinesColgadas(t *testing.T) {
	tmpDir := t.TempDir()
	socketPath := tmpDir + "/shinro"
	os.Setenv("SHINRO_SOCKET_PATH", socketPath)
	defer os.Unsetenv("SHINRO_SOCKET_PATH")

	registry := NewDefaultRegistry(systemProviderForTest(), weatherProviderForTest())
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

	baseline := runtime.NumGoroutine()

	// Conectar y desconectar varios clientes, cada uno con un módulo
	// periódico activo (para arrancar pumps que deben terminar al irse).
	for range 10 {
		conn, err := net.Dial("unix", socketPath)
		if err != nil {
			t.Fatalf("no se pudo conectar al socket: %v", err)
		}

		hello := map[string]any{
			"type": "hello",
			"intervals": map[string]int{
				"system": 1,
			},
		}
		helloBytes, _ := json.Marshal(hello)
		if _, err := conn.Write(append(helloBytes, '\n')); err != nil {
			t.Fatalf("error enviando hello: %v", err)
		}

		// Dar tiempo a que el pump arranque.
		time.Sleep(30 * time.Millisecond)
		conn.Close()
	}

	// Tras cerrarlos, las goroutines de los clientes deben terminar. Se
	// espera con margen porque el cierre no es instantáneo.
	deadline = time.Now().Add(10 * time.Second)
	var current int
	for time.Now().Before(deadline) {
		current = runtime.NumGoroutine()
		if current <= baseline+2 {
			break
		}
		time.Sleep(50 * time.Millisecond)
	}

	if current > baseline+2 {
		buf := make([]byte, 1<<16)
		n := runtime.Stack(buf, true)
		t.Fatalf("fuga de goroutines: baseline=%d actual=%d\n%s", baseline, current, buf[:n])
	}

	cancel()
	select {
	case <-errCh:
	case <-time.After(5 * time.Second):
		t.Fatal("timeout esperando a que se detuviera el servidor")
	}
}
