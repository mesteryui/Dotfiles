package socket

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"shinro-backend/internal/system"
	"shinro-backend/internal/weather"
)

func TestAcquireLockExclusivity(t *testing.T) {
	tmpDir := t.TempDir()
	sockPath := filepath.Join(tmpDir, "shinro")

	// 1. Primer proceso adquiere el lock con éxito
	lock1, err := AcquireLock(sockPath)
	if err != nil {
		t.Fatalf("esperaba adquirir lock1 con éxito, got error: %v", err)
	}
	defer lock1.Close()

	// 2. Segundo intento debe fallar de inmediato con ErrAlreadyRunning (en 0 ms)
	lock2, err := AcquireLock(sockPath)
	if err == nil {
		lock2.Close()
		t.Fatal("esperaba que lock2 fallara por estar ya adquirido, pero tuvo éxito")
	}
	if !errors.Is(err, ErrAlreadyRunning) {
		t.Fatalf("esperaba ErrAlreadyRunning, got: %v", err)
	}

	// 3. Al liberar lock1, debe ser posible adquirirlo de nuevo
	if err := lock1.Close(); err != nil {
		t.Fatalf("error cerrando lock1: %v", err)
	}

	lock3, err := AcquireLock(sockPath)
	if err != nil {
		t.Fatalf("esperaba adquirir lock3 tras liberar lock1, got: %v", err)
	}
	defer lock3.Close()
}

func TestServerRejectsDuplicateInstance(t *testing.T) {
	tmpDir := t.TempDir()
	sockPath := filepath.Join(tmpDir, "shinro")

	reg1 := NewDefaultRegistry(system.New(), weather.New())
	srv1 := NewServer(reg1, nil)
	srv1.path = sockPath

	ctx1, cancel1 := context.WithCancel(context.Background())
	defer cancel1()

	started := make(chan error, 1)
	go func() {
		started <- srv1.Start(ctx1)
	}()

	// Esperar a que el socket exista
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(sockPath); err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}

	// Intentar arrancar una segunda instancia sobre el mismo socket
	reg2 := NewDefaultRegistry(system.New(), weather.New())
	srv2 := NewServer(reg2, nil)
	srv2.path = sockPath

	ctx2, cancel2 := context.WithCancel(context.Background())
	defer cancel2()

	err2 := srv2.Start(ctx2)
	if err2 == nil {
		t.Fatal("esperaba que srv2.Start fallara con ErrAlreadyRunning, pero tuvo éxito")
	}
	if !errors.Is(err2, ErrAlreadyRunning) {
		t.Fatalf("esperaba ErrAlreadyRunning en srv2, got: %v", err2)
	}

	// Comprobar que el socket del primer servidor no fue borrado ni alterado
	if _, err := os.Stat(sockPath); err != nil {
		t.Fatalf("el socket del primer servidor desapareció tras el intento de srv2: %v", err)
	}

	// Parar srv1 limpiamente
	cancel1()
	select {
	case err := <-started:
		if err != nil {
			t.Fatalf("srv1 terminó con error: %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("timeout esperando graceful shutdown de srv1")
	}
}
