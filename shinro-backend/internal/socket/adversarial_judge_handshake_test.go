package socket

import (
	"context"
	"net"
	"os"
	"testing"
	"time"

	"shinro-backend/internal/logger"
	"shinro-backend/internal/system"
	"shinro-backend/internal/weather"
)

// Verifica que el plazo de handshake no se desactive al recibir una primera
// línea inválida o vacía: un cliente que no envía un hello/get válido debe ser
// cerrado tras handshakeTimeout, no quedarse ocupando un slot indefinidamente.
func TestHandshakeDeadlineNotClearedByInvalidFirstLine(t *testing.T) {
	logger.Init()

	tmpDir := t.TempDir()
	socketPath := tmpDir + "/shinro"
	t.Setenv("SHINRO_SOCKET_PATH", socketPath)

	sysProvider := system.New()
	weatherProvider := weather.New()
	registry := NewDefaultRegistry(sysProvider, weatherProvider)
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
		t.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	// Primera línea no válida como mensaje de protocolo.
	if _, err := conn.Write([]byte("\n")); err != nil {
		t.Fatalf("write: %v", err)
	}

	// Esperar más que handshakeTimeout (5s). Si el servidor limpió el deadline,
	// la conexión seguirá abierta y esta lectura terminará por timeout del
	// cliente. Si el servidor mantiene el deadline, cerrará la conexión.
	time.Sleep(handshakeTimeout + 1500*time.Millisecond)

	_ = conn.SetReadDeadline(time.Now().Add(1 * time.Second))
	buf := make([]byte, 1)
	n, err := conn.Read(buf)
	if n > 0 {
		t.Fatalf("no se esperaba respuesta, got %q", buf[:n])
	}
	if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
		t.Fatalf("el servidor mantuvo la conexión abierta tras una primera línea inválida; el deadline de handshake se limpió antes de validar el mensaje")
	}
	// EOF u otro error de conexión cerrada = comportamiento esperado.
	_ = err
}
