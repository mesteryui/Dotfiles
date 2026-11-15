package socket

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"shinro-backend/internal/logger"
)

// newTestClient crea un cliente aislado (sin servidor) para probar los
// módulos directamente.
func newTestClient(t *testing.T) *client {
	t.Helper()
	local, peer := net.Pipe()
	t.Cleanup(func() {
		local.Close()
		peer.Close()
	})
	return &client{
		conn:   local,
		reader: bufio.NewReader(local),
		send:   make(chan []byte, 16),
		done:   make(chan struct{}),
	}
}

// TestWeatherHelloNoBorraLaCiudad comprueba que un hello de reconfiguración
// sin "location" no deja el clima sin ciudad.
//
// Antes, el módulo de weather sobrescribía c.city con el valor recibido
// (vacío si no venía location), de modo que un hello de reconfiguración
// dejaba el clima Asking for a location.
func TestWeatherHelloNoBorraLaCiudad(t *testing.T) {
	c := newTestClient(t)
	m := &weatherModule{}

	// Primer hello: con ciudad.
	hello, _ := json.Marshal(map[string]any{
		"location":  map[string]string{"mode": "manual", "city": "Vigo"},
		"intervals": map[string]int{"weather": 0},
	})
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(hello, &raw); err != nil {
		t.Fatalf("no se pudo preparar el hello: %v", err)
	}
	m.HandleHello(c, raw)

	c.mu.Lock()
	city := c.city
	c.mu.Unlock()
	if city != "Vigo" {
		t.Fatalf("esperaba la ciudad Vigo, got %q", city)
	}

	// Segundo hello: sin location (reconfiguración de intervalos).
	reconf, _ := json.Marshal(map[string]any{
		"intervals": map[string]int{"weather": 0},
	})
	raw = nil
	if err := json.Unmarshal(reconf, &raw); err != nil {
		t.Fatalf("no se pudo preparar la reconfiguración: %v", err)
	}
	m.HandleHello(c, raw)

	c.mu.Lock()
	city = c.city
	c.mu.Unlock()
	if city != "Vigo" {
		t.Fatalf("la reconfiguración borró la ciudad: got %q", city)
	}
}

// TestReadClientLineRechazaLineaDemasiadoLarga comprueba que una línea por
// encima del máximo se rechaza en lugar de acumularse en memoria.
func TestReadClientLineRechazaLineaDemasiadoLarga(t *testing.T) {
	r := bufio.NewReader(strings.NewReader(strings.Repeat("a", maxClientLineBytes+10) + "\n"))

	if _, err := readClientLine(r); err == nil {
		t.Fatal("esperaba error por línea demasiado larga")
	} else if err != errLineTooLong {
		t.Fatalf("esperaba errLineTooLong, got %v", err)
	}
}

// TestReadClientLineAceptaLineaNormal comprueba que una línea dentro del
// límite (y mayor que el buffer interno) se lee bien.
func TestReadClientLineAceptaLineaNormal(t *testing.T) {
	payload := strings.Repeat("b", 9000) // > buffer interno de bufio (4096)
	r := bufio.NewReader(strings.NewReader(payload + "\n"))

	line, err := readClientLine(r)
	if err != nil {
		t.Fatalf("esperaba leer la línea: %v", err)
	}
	if len(line) != len(payload)+1 {
		t.Fatalf("esperaba %d bytes, got %d", len(payload)+1, len(line))
	}
}

// TestServidorCierraConexionConLineaGigante comprueba el comportamiento de
// extremo a extremo: un cliente que manda una línea enorme no puede hacer
// crecer la memoria del daemon; el servidor lo echa.
func TestServidorCierraConexionConLineaGigante(t *testing.T) {
	logger.Init()

	tmpDir := t.TempDir()
	socketPath := tmpDir + "/shinro"
	os.Setenv("SHINRO_SOCKET_PATH", socketPath)
	defer os.Unsetenv("SHINRO_SOCKET_PATH")

	registry := NewRegistry()
	registry.Register(&pingModule{})
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

	// Mandar una línea gigante (> 1 MiB) sin salto de línea final primero.
	grande := strings.Repeat("x", maxClientLineBytes+1024)
	if _, err := conn.Write([]byte(grande)); err != nil {
		t.Fatalf("error escribiendo la línea gigante: %v", err)
	}
	if _, err := conn.Write([]byte("\n")); err != nil {
		t.Fatalf("error cerrando la línea: %v", err)
	}

	// El servidor debe cerrar la conexión: la lectura termina con EOF.
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	buf := make([]byte, 64)
	for {
		_, err := conn.Read(buf)
		if err != nil {
			break // EOF: el servidor echó al cliente
		}
	}

	cancel()
	select {
	case <-errCh:
	case <-time.After(5 * time.Second):
		t.Fatal("timeout esperando a que se detuviera el servidor")
	}
}
