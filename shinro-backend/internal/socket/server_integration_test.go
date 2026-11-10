package socket

import (
	"context"
	"encoding/json"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"shinro-backend/internal/logger"
	"shinro-backend/internal/system"
	"shinro-backend/internal/weather"
)

func TestIntegrationSocketHelloAndUpdates(t *testing.T) {
	logger.Init()

	// Socket temporal para no interferir con el socket real del usuario.
	tmpDir := t.TempDir()
	socketPath := tmpDir + "/shinro"
	os.Setenv("SHINRO_SOCKET_PATH", socketPath)
	defer os.Unsetenv("SHINRO_SOCKET_PATH")

	sysProvider := system.New()
	weatherProvider := weather.New()

	registry := NewDefaultRegistry(sysProvider, weatherProvider)
	srv := NewServer(registry, nil)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	errCh := make(chan error, 1)
	go func() {
		errCh <- srv.Start(ctx)
	}()

	// Esperar a que el socket exista.
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(socketPath); err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}

	// Conectar cliente Unix real.
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("no se pudo conectar al socket: %v", err)
	}
	defer conn.Close()

	// Enviar hello con system activado, weather desactivado.
	hello := map[string]interface{}{
		"type": "hello",
		"location": map[string]string{
			"mode": "manual",
			"city": "Vigo",
		},
		"intervals": map[string]int{
			"system":  1,
			"weather": 0,
		},
		"lang": "es",
	}
	helloBytes, _ := json.Marshal(hello)
	if _, err := conn.Write(append(helloBytes, '\n')); err != nil {
		t.Fatalf("error enviando hello: %v", err)
	}

	// Leer respuesta de hello.
	response, err := readLine(conn, 5*time.Second)
	if err != nil {
		t.Fatalf("error leyendo respuesta hello: %v", err)
	}
	var helloResp map[string]interface{}
	if err := json.Unmarshal([]byte(response), &helloResp); err != nil {
		t.Fatalf("no se pudo parsear respuesta hello: %v", err)
	}
	if helloResp["type"] != "hello" {
		t.Fatalf("esperaba tipo hello, got %v", helloResp["type"])
	}
	if helloResp["ok"] != true {
		t.Fatalf("esperaba ok=true, got %v", helloResp["ok"])
	}

	// Leer un update de system.
	update, err := readLine(conn, 5*time.Second)
	if err != nil {
		t.Fatalf("error leyendo update de system: %v", err)
	}
	var updateMsg map[string]interface{}
	if err := json.Unmarshal([]byte(update), &updateMsg); err != nil {
		t.Fatalf("no se pudo parsear update: %v", err)
	}
	if updateMsg["type"] != "update" {
		t.Fatalf("esperaba tipo update, got %v", updateMsg["type"])
	}
	if updateMsg["module"] != "system" {
		t.Fatalf("esperaba module system, got %v", updateMsg["module"])
	}
	data, ok := updateMsg["data"].(map[string]interface{})
	if !ok {
		t.Fatalf("esperaba data como objeto, got %T", updateMsg["data"])
	}
	// Verificar que tiene campos esperados de system.
	for _, field := range []string{"ram_percent", "cpu_cores", "uptime_seconds", "hostname"} {
		if _, ok := data[field]; !ok {
			t.Fatalf("system data no tiene campo %s", field)
		}
	}

	// Probar health check (ping) mediante get.
	getPing := map[string]interface{}{
		"type":   "get",
		"module": "ping",
	}
	getBytes, _ := json.Marshal(getPing)
	if _, err := conn.Write(append(getBytes, '\n')); err != nil {
		t.Fatalf("error enviando get ping: %v", err)
	}
	pingResp, err := readLine(conn, 5*time.Second)
	if err != nil {
		t.Fatalf("error leyendo respuesta ping: %v", err)
	}
	var pingMsg map[string]interface{}
	if err := json.Unmarshal([]byte(pingResp), &pingMsg); err != nil {
		t.Fatalf("no se pudo parsear respuesta ping: %v", err)
	}
	if pingMsg["module"] != "ping" {
		t.Fatalf("esperaba module ping, got %v", pingMsg["module"])
	}
	pingData, ok := pingMsg["data"].(map[string]interface{})
	if !ok {
		t.Fatalf("esperaba data como objeto en ping, got %T", pingMsg["data"])
	}
	if pingData["ok"] != "true" {
		t.Fatalf("esperaba ok=true en ping, got %v", pingData["ok"])
	}

	// Probar módulo desconocido.
	getUnknown := map[string]interface{}{
		"type":   "get",
		"module": "noexist",
	}
	getUnknownBytes, _ := json.Marshal(getUnknown)
	if _, err := conn.Write(append(getUnknownBytes, '\n')); err != nil {
		t.Fatalf("error enviando get noexist: %v", err)
	}
	errResp, err := readLine(conn, 5*time.Second)
	if err != nil {
		t.Fatalf("error leyendo respuesta error: %v", err)
	}
	var errMsg map[string]interface{}
	if err := json.Unmarshal([]byte(errResp), &errMsg); err != nil {
		t.Fatalf("no se pudo parsear respuesta error: %v", err)
	}
	if errMsg["type"] != "error" {
		t.Fatalf("esperaba tipo error, got %v", errMsg["type"])
	}

	// Detener servidor.
	cancel()
	select {
	case err := <-errCh:
		if err != nil && err != context.Canceled {
			t.Fatalf("error al detener servidor: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timeout esperando a que se detuviera el servidor")
	}
}

// readLine lee una línea terminada en \n del conexión con timeout.
func readLine(conn net.Conn, timeout time.Duration) (string, error) {
	conn.SetReadDeadline(time.Now().Add(timeout))
	defer conn.SetReadDeadline(time.Time{})

	var buf strings.Builder
	tmp := make([]byte, 1)
	for {
		n, err := conn.Read(tmp)
		if n > 0 {
			buf.Write(tmp[:n])
			if tmp[0] == '\n' {
				return buf.String(), nil
			}
		}
		if err != nil {
			return buf.String(), err
		}
	}
}
