package connectivity

import (
	"context"
	"os"
	"testing"
	"time"
)

// TestNMEstadoDesconocidoNoEsOffline comprueba que un estado desconocido de
// NetworkManager no se interpreta como "sin conexión".
//
// Si se hiciera, el monitor declararía la red caída al arrancar (cuando la
// lectura inicial de propiedades falla) y no volvería a comprobar la
// conexión: el usuario se quedaría sin clima hasta reiniciar el daemon.
func TestNMEstadoDesconocidoNoEsOffline(t *testing.T) {
	m := &nmMonitor{
		subs: make(map[chan bool]struct{}),
	}

	if m.isDefinitelyOffline() {
		t.Fatal("un estado desconocido no debe considerarse offline")
	}

	// Con el estado ya conocido, sí se puede afirmar.
	m.state = nmStateDisconnected
	if !m.isDefinitelyOffline() {
		t.Fatal("esperaba isDefinitelyOffline=true con estado disconnected")
	}

	m.state = nmStateConnectedGlobal
	if m.isDefinitelyOffline() {
		t.Fatal("esperaba isDefinitelyOffline=false con estado connected_global")
	}
}

// TestMonitorEstadoDesconocidoAsumeOnline comprueba que, mientras no se sabe
// el estado de la red, se asume que hay conexión: así la primera petición de
// clima no falla con un error por un estado todavía sin resolver.
func TestMonitorEstadoDesconocidoAsumeOnline(t *testing.T) {
	os.Setenv("SHINRO_CONNECTIVITY_DISABLE_NM", "1")
	defer os.Unsetenv("SHINRO_CONNECTIVITY_DISABLE_NM")

	m := New("", time.Second)
	defer m.Close()

	if m.State() != StateUnknown {
		t.Fatalf("esperaba StateUnknown, got %s", m.State())
	}
	if !m.IsOnline() {
		t.Fatal("con el estado desconocido se debe asumir que hay conexión")
	}
}

// TestMonitorRecuperaLaRed comprueba que, tras una desconexión, el monitor
// vuelve a detectar la conexión y lo notifica a los suscriptores: es lo que
// dispara el refresco inmediato del clima.
func TestMonitorRecuperaLaRed(t *testing.T) {
	os.Setenv("SHINRO_CONNECTIVITY_DISABLE_NM", "1")
	defer os.Unsetenv("SHINRO_CONNECTIVITY_DISABLE_NM")

	m := New("http://127.0.0.1:1/generate_204", 100*time.Millisecond)
	defer m.Close()

	ch := m.Subscribe()
	defer m.Unsubscribe(ch)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	go m.Run(ctx)

	// El endpoint no existe: el estado debe pasar a offline. El primer valor
	// recibido es el estado inicial (unknown), así que se espera al cambio.
	timeout := time.After(5 * time.Second)
waitOffline:
	for {
		select {
		case state := <-ch:
			if state == StateOffline {
				break waitOffline
			}
		case <-timeout:
			t.Fatal("timeout esperando el estado offline")
		}
	}

	// Con ReportSuccess (una petición externa que sí funcionó) el monitor
	// debe pasar a online y avisar: es la vía por la que el clima recupera
	// la conexión más rápido que el siguiente tick.
	m.ReportSuccess()

	select {
	case state := <-ch:
		if state != StateOnline {
			t.Fatalf("esperaba online, got %s", state)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("timeout esperando el estado online")
	}
}
