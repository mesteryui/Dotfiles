package socket

import (
	"context"
	"encoding/json"
	"net"
	"os"
	"sync/atomic"
	"testing"
	"time"
)

// panicModule entra en panic al enviar actualizaciones. Simula un módulo con
// un fallo interno (por ejemplo, el proveedor de clima devolviendo basura).
type panicModule struct {
	sends int32
}

func (m *panicModule) Name() string { return "panico" }

func (m *panicModule) HandleHello(c *client, raw map[string]json.RawMessage) {
	var payload struct {
		Intervals struct {
			Panico int `json:"panico"`
		} `json:"intervals"`
	}
	if intRaw, ok := raw["intervals"]; ok {
		_ = json.Unmarshal(intRaw, &payload.Intervals)
	}

	c.setModInterval(m.Name(), payload.Intervals.Panico)
	c.setSubscribed(m.Name(), true)
	c.startPump(m)
}

func (m *panicModule) HandleGet(c *client, raw map[string]json.RawMessage) error { return nil }

func (m *panicModule) SendUpdate(c *client) error {
	atomic.AddInt32(&m.sends, 1)
	panic("fallo interno del módulo")
}

// TestPumpSobreviveAPanic comprueba que un módulo que entra en panic al
// enviar actualizaciones no tumba el daemon: el pump sigue vivo y el
// servidor sigue atendiendo a otros clientes.
func TestPumpSobreviveAPanic(t *testing.T) {
	tmpDir := t.TempDir()
	socketPath := tmpDir + "/shinro"
	os.Setenv("SHINRO_SOCKET_PATH", socketPath)
	defer os.Unsetenv("SHINRO_SOCKET_PATH")

	registry := NewRegistry()
	mod := &panicModule{}
	registry.Register(mod)
	registry.Register(&pingModule{})

	srv := NewServer(registry, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	errCh := make(chan error, 1)
	go func() { errCh <- srv.Start(ctx) }()

	// Esperar a que el socket exista.
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

	// Suscribirse al módulo que entra en panic.
	hello := map[string]interface{}{
		"type": "hello",
		"intervals": map[string]int{
			"panico": 1,
		},
	}
	helloBytes, _ := json.Marshal(hello)
	if _, err := conn.Write(append(helloBytes, '\n')); err != nil {
		t.Fatalf("error enviando hello: %v", err)
	}

	// El módulo que entra en panic debe reintentar: el pump no muere con el
	// primer fallo, sino que siguevivo.
	deadline = time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		if atomic.LoadInt32(&mod.sends) >= 3 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if sends := atomic.LoadInt32(&mod.sends); sends < 3 {
		t.Fatalf("esperaba varios envíos del módulo tras el panic, got %d", sends)
	}

	// El servidor debe seguir respondiendo: el ping no depende del módulo
	// que entra en panic.
	deadline = time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		get := map[string]interface{}{"type": "get", "module": "ping"}
		getBytes, _ := json.Marshal(get)
		if _, err := conn.Write(append(getBytes, '\n')); err != nil {
			t.Fatalf("error enviando get ping: %v", err)
		}
		line, err := readLine(conn, 2*time.Second)
		if err != nil {
			continue
		}
		var msg map[string]interface{}
		if err := json.Unmarshal([]byte(line), &msg); err != nil {
			continue
		}
		if msg["module"] == "ping" {
			cancel()
			select {
			case <-errCh:
			case <-time.After(5 * time.Second):
				t.Fatal("timeout esperando a que se detuviera el servidor")
			}
			return
		}
	}

	t.Fatal("el servidor dejó de responder tras el panic del módulo")
}
