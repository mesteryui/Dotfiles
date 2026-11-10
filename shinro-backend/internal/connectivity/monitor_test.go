package connectivity

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"sync/atomic"
	"testing"
	"time"
)

func TestMonitorReflectsConnectivityChanges(t *testing.T) {
	// Forzar polling HTTP para el test (NetworkManager está activo en el sistema).
	os.Setenv("SHINRO_CONNECTIVITY_DISABLE_NM", "1")
	defer os.Unsetenv("SHINRO_CONNECTIVITY_DISABLE_NM")

	var online int32 = 1
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if atomic.LoadInt32(&online) == 1 {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(`{"ok":true}`))
		} else {
			w.WriteHeader(http.StatusServiceUnavailable)
		}
	}))
	defer srv.Close()

	m := New(srv.URL, 50*time.Millisecond)
	ch := m.Subscribe()
	defer m.Unsubscribe(ch)

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	go m.Run(ctx)

	// El primer estado emitido puede ser Unknown; esperamos hasta ver Online.
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		select {
		case st := <-ch:
			if st == StateOnline {
				goto onlineSeen
			}
		case <-time.After(50 * time.Millisecond):
		}
	}
	t.Fatal("no se detectó estado online inicial")

onlineSeen:
	// Pasar a offline.
	atomic.StoreInt32(&online, 0)
	select {
	case st := <-ch:
		if st != StateOffline {
			t.Fatalf("esperaba offline, got %s", st)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timeout esperando transición a offline")
	}

	// Volver a online.
	atomic.StoreInt32(&online, 1)
	select {
	case st := <-ch:
		if st != StateOnline {
			t.Fatalf("esperaba online, got %s", st)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timeout esperando transición a online")
	}
}
