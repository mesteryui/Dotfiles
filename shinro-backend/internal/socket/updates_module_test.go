package socket

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"shinro-backend/internal/updates"
)

type fakeBackendForSocket struct {
	id    string
	pkgs  []updates.Package
	calls atomic.Int32
}

func (f *fakeBackendForSocket) ID() string        { return f.id }
func (f *fakeBackendForSocket) Command() []string { return []string{"fake-" + f.id} }
func (f *fakeBackendForSocket) Parse(stdout []byte, exit int) ([]updates.Package, error) {
	f.calls.Add(1)
	return f.pkgs, nil
}
func (f *fakeBackendForSocket) UpdateCommands() [][]string {
	return [][]string{{"fake-update-" + f.id}}
}

type fakeExecutorForSocket struct {
	calls atomic.Int32
}

func (f *fakeExecutorForSocket) Run(ctx context.Context, argv []string) (updates.Output, error) {
	f.calls.Add(1)
	return updates.Output{Exit: 0}, nil
}

func readUpdatesMessage(reader *bufio.Reader, conn net.Conn, timeout time.Duration) (map[string]any, error) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		_ = conn.SetReadDeadline(deadline)
		line, err := reader.ReadString('\n')
		if err != nil {
			return nil, err
		}
		var msg map[string]any
		if err := json.Unmarshal([]byte(strings.TrimSpace(line)), &msg); err != nil {
			continue
		}
		if msg["type"] == "update" && msg["module"] == "updates" {
			return msg, nil
		}
	}
	return nil, context.DeadlineExceeded
}

func TestUpdatesModuleProtocol(t *testing.T) {
	tmpDir := t.TempDir()
	socketPath := filepath.Join(tmpDir, "shinro")
	t.Setenv("SHINRO_SOCKET_PATH", socketPath)

	fb := &fakeBackendForSocket{
		id: "pacman",
		pkgs: []updates.Package{
			{Name: "neovim", Old: "0.9.0", New: "0.10.0", Backend: "pacman"},
		},
	}
	exec := &fakeExecutorForSocket{}
	online := atomic.Bool{}
	online.Store(true)
	updProvider := updates.New([]updates.Backend{fb}, exec, func() bool { return online.Load() })

	registry := NewRegistry()
	updMod := NewUpdatesModule(updProvider)
	registry.Register(updMod)

	srv := NewServer(registry, nil)
	updProvider.SetBroadcast(srv.WakeUpdateClients)

	ctx := t.Context()

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

	reader := bufio.NewReader(conn)

	// 1. Hello subscribes to updates
	hello := map[string]any{
		"type": "hello",
		"intervals": map[string]int{
			"updates": 300,
		},
		"updates": map[string]any{
			"backends": []string{"pacman"},
		},
	}
	helloBytes, _ := json.Marshal(hello)
	if _, err := conn.Write(append(helloBytes, '\n')); err != nil {
		t.Fatalf("escribiendo hello: %v", err)
	}

	// Read messages until initial check completes
	var (
		count float64
		msg   map[string]any
	)
	initDeadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(initDeadline) {
		msg, err = readUpdatesMessage(reader, conn, time.Second)
		if err != nil {
			break
		}
		if d, ok := msg["data"].(map[string]any); ok {
			checking, _ := d["checking"].(bool)
			if !checking {
				count, _ = d["count"].(float64)
				if count > 0 {
					break
				}
			}
		}
	}
	if count != 1 {
		t.Fatalf("count = %v, quiero 1 tras comprobación inicial", count)
	}

	// 2. Action: get
	getReq := map[string]any{
		"type":   "get",
		"module": "updates",
		"action": "get",
	}
	getBytes, _ := json.Marshal(getReq)
	if _, err := conn.Write(append(getBytes, '\n')); err != nil {
		t.Fatalf("escribiendo get: %v", err)
	}

	msg, err = readUpdatesMessage(reader, conn, 5*time.Second)
	if err != nil {
		t.Fatalf("leyendo get response: %v", err)
	}

	// 3. Action: check
	checkReq := map[string]any{
		"type":   "get",
		"module": "updates",
		"action": "check",
	}
	checkBytes, _ := json.Marshal(checkReq)
	if _, err := conn.Write(append(checkBytes, '\n')); err != nil {
		t.Fatalf("escribiendo check: %v", err)
	}

	receivedFinal := false
	checkDeadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(checkDeadline) && !receivedFinal {
		m, err := readUpdatesMessage(reader, conn, time.Second)
		if err != nil {
			break
		}
		if d, ok := m["data"].(map[string]any); ok {
			if checking, _ := d["checking"].(bool); !checking {
				receivedFinal = true
			}
		}
	}
	if !receivedFinal {
		t.Fatalf("no se recibió el resultado final del check")
	}

	// 4. Action: update — el backend ya no ejecuta actualizaciones: debe
	// devolver un error indicando que se use update_script en un terminal.
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	updateReq := map[string]any{
		"type":   "get",
		"module": "updates",
		"action": "update",
	}
	updBytes, _ := json.Marshal(updateReq)
	if _, err := conn.Write(append(updBytes, '\n')); err != nil {
		t.Fatalf("escribiendo update: %v", err)
	}
	gotError := false
	for i := 0; i < 5; i++ {
		line, err := reader.ReadString('\n')
		if err != nil {
			break
		}
		var msg map[string]any
		if err := json.Unmarshal([]byte(strings.TrimSpace(line)), &msg); err != nil {
			continue
		}
		if msg["type"] == "error" {
			gotError = true
			break
		}
	}
	if !gotError {
		t.Fatalf("se esperaba un error al pedir update por socket")
	}

	// 5. Offline behavior
	online.Store(false)
	snapBefore := updProvider.Snapshot()
	stateOffline := updProvider.Check(context.Background())
	if stateOffline.CheckedAt != snapBefore.CheckedAt {
		t.Fatalf("offline check no debió actualizar checked_at")
	}
}
