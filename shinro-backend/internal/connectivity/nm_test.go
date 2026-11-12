package connectivity

import (
	"testing"

	"github.com/godbus/dbus/v5"
)

func TestNMMonitorStateEvaluation(t *testing.T) {
	m := &nmMonitor{
		subs: make(map[chan bool]struct{}),
	}

	// 1. Estado inicial desconocido -> no online
	if m.evalOnline() {
		t.Fatal("esperaba false para estado desconocido")
	}

	// 2. State = ConnectedGlobal (70) -> online
	m.state = nmStateConnectedGlobal
	if !m.evalOnline() {
		t.Fatal("esperaba true para nmStateConnectedGlobal")
	}

	// 3. State = Connecting (40), Connectivity = Full (4) -> online
	m.state = nmStateConnecting
	m.connectivity = nmConnectivityFull
	if !m.evalOnline() {
		t.Fatal("esperaba true para nmConnectivityFull")
	}

	// 4. Connectivity = Portal (2) -> offline
	m.connectivity = nmConnectivityPortal
	m.state = nmStateConnecting
	if m.evalOnline() {
		t.Fatal("esperaba false para captive portal")
	}
	if !m.isDefinitelyOffline() {
		t.Fatal("esperaba isDefinitelyOffline=true para portal")
	}

	// 5. State = Disconnected (20) -> definitely offline
	m.state = nmStateDisconnected
	m.connectivity = nmConnectivityUnknown
	if !m.isDefinitelyOffline() {
		t.Fatal("esperaba isDefinitelyOffline=true para disconnected")
	}
}

func TestNMMonitorPropertiesAndStateChanged(t *testing.T) {
	m := &nmMonitor{
		subs: make(map[chan bool]struct{}),
	}
	ch := m.Subscribe()
	defer m.Unsubscribe(ch)

	// Leer primer valor emitido al suscribir
	initial := <-ch
	if initial {
		t.Fatalf("esperaba initial false, got true")
	}

	// Simular StateChanged a ConnectedGlobal
	m.handleStateChanged(nmStateConnectedGlobal)
	select {
	case online := <-ch:
		if !online {
			t.Fatalf("esperaba online true tras StateChanged, got false")
		}
	default:
		t.Fatal("no se emitió evento tras StateChanged")
	}

	// Simular PropertiesChanged a Disconnected
	m.handlePropertiesChanged(map[string]dbus.Variant{
		"State":        dbus.MakeVariant(nmStateDisconnected),
		"Connectivity": dbus.MakeVariant(nmConnectivityNone),
	})
	select {
	case online := <-ch:
		if online {
			t.Fatalf("esperaba online false tras desconexión, got true")
		}
	default:
		t.Fatal("no se emitió evento tras PropertiesChanged")
	}
}
