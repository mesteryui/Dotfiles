package socket

import (
	"context"
	"encoding/json"
	"net"
	"os"
	"strings"
	"testing"
	"time"
)

// testModule es un módulo de mentira con un número de envíos controlado, para
// comprobar que el informe de salud refleja lo que ha pasado.
type testModule struct {
	name  string
	sends int
	fail  bool
	err   error

	// deadPump simula un módulo que se suscribe pero cuyo pump no arranca:
	// el caso de un pump muerto.
	deadPump bool
}

func (m *testModule) Name() string { return m.name }

// HandleHello se suscribe y arranca el pump, igual que hacen los módulos
// reales (salvo que deadPump esté a true).
func (m *testModule) HandleHello(c *client, raw map[string]json.RawMessage) {
	var payload struct {
		Intervals map[string]int `json:"intervals"`
	}
	if intRaw, ok := raw["intervals"]; ok {
		_ = json.Unmarshal(intRaw, &payload.Intervals)
	}
	interval := payload.Intervals[m.name]
	c.setModInterval(m.name, interval)
	c.setSubscribed(m.name, interval > 0)
	if interval > 0 && !m.deadPump {
		c.startPump(m)
	}
}

func (m *testModule) HandleGet(c *client, raw map[string]json.RawMessage) error {
	return m.SendUpdate(c)
}

func (m *testModule) SendUpdate(c *client) error {
	if m.fail {
		return m.err
	}
	m.sends++
	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": m.name,
		"data":   map[string]any{"ok": "true"},
	})
	c.write(writeBuf(msg))
	return nil
}

// startTestServer arranca un servidor con los módulos indicados y devuelve su
// ruta de socket.
func startTestServer(t *testing.T, mods ...Module) (string, *Server) {
	t.Helper()

	tmpDir := t.TempDir()
	socketPath := tmpDir + "/shinro"
	os.Setenv("SHINRO_SOCKET_PATH", socketPath)
	t.Cleanup(func() { os.Unsetenv("SHINRO_SOCKET_PATH") })

	registry := NewRegistry()
	for _, m := range mods {
		registry.Register(m)
	}
	srv := NewServer(registry, nil)

	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)

	errCh := make(chan error, 1)
	go func() { errCh <- srv.Start(ctx) }()

	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(socketPath); err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}

	t.Cleanup(func() {
		cancel()
		select {
		case <-errCh:
		case <-time.After(5 * time.Second):
			t.Error("timeout esperando a que se detuviera el servidor")
		}
	})

	return socketPath, srv
}

// pedirGet hace una petición puntual a un módulo y descarta la respuesta.
func pedirGet(t *testing.T, socketPath, module string) {
	t.Helper()

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("no se pudo conectar al socket: %v", err)
	}
	defer conn.Close()

	payload := `{"type":"get","module":"` + module + `"}` + "\n"
	if _, err := conn.Write([]byte(payload)); err != nil {
		t.Fatalf("error enviando get %s: %v", module, err)
	}
	// Leer la respuesta para que el servidor termine de atenderla.
	conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	buf := make([]byte, 4096)
	for {
		n, err := conn.Read(buf)
		if n > 0 && strings.Contains(string(buf[:n]), "\n") {
			break
		}
		if err != nil {
			break
		}
	}
}

// pedirPing hace una petición de ping y devuelve el informe.
func pedirPing(t *testing.T, socketPath string) Health {
	t.Helper()

	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("no se pudo conectar al socket: %v", err)
	}
	defer conn.Close()

	if _, err := conn.Write([]byte(`{"type":"get","module":"ping"}` + "\n")); err != nil {
		t.Fatalf("error enviando get ping: %v", err)
	}

	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	buf := make([]byte, 0, 8192)
	tmp := make([]byte, 4096)
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		n, err := conn.Read(tmp)
		if n > 0 {
			buf = append(buf, tmp[:n]...)
			for line := range strings.SplitSeq(string(buf), "\n") {
				if !strings.Contains(line, "\"ping\"") {
					continue
				}
				var resp struct {
					Data Health `json:"data"`
				}
				if err := json.Unmarshal([]byte(line), &resp); err != nil {
					continue
				}
				return resp.Data
			}
		}
		if err != nil {
			break
		}
	}
	t.Fatalf("no se recibió el informe de ping")
	return Health{}
}

// TestPingInformaDelEstadoDeLosModulos comprueba que el ping no se limita a
// decir "ok": informa del estado real de cada módulo.
func TestPingInformaDelEstadoDeLosModulos(t *testing.T) {
	saludable := &testModule{name: "sano"}
	fallido := &testModule{
		name: "roto",
		fail: true,
		err:  errPrueba{},
	}

	socketPath, _ := startTestServer(t, &pingModule{}, saludable, fallido)

	// Ejercitar el módulo roto: el error solo se registra cuando el módulo
	// intenta enviar algo.
	pedirGet(t, socketPath, "roto")

	h := pedirPing(t, socketPath)

	if h.OK != "true" {
		t.Fatalf("esperaba ok=true, got %q", h.OK)
	}
	if h.Status != HealthStatusError {
		t.Fatalf("esperaba estado error por el módulo roto, got %q", h.Status)
	}
	if len(h.Modules) != 3 {
		t.Fatalf("esperaba 3 módulos, got %d", len(h.Modules))
	}

	porNombre := map[string]ModuleHealth{}
	for _, m := range h.Modules {
		porNombre[m.Name] = m
	}

	if porNombre["sano"].Status != ModuleStatusIdle {
		t.Fatalf("esperaba idle para el módulo sano, got %q", porNombre["sano"].Status)
	}
	if porNombre["roto"].Status != ModuleStatusError {
		t.Fatalf("esperaba error para el módulo roto, got %q", porNombre["roto"].Status)
	}
	if porNombre["roto"].LastError == "" {
		t.Fatal("esperaba el mensaje de error del módulo roto")
	}
	if porNombre["roto"].Errors != 1 {
		t.Fatalf("esperaba 1 error, got %d", porNombre["roto"].Errors)
	}

	// El problema debe ser legible y mencionar el módulo.
	if len(h.Problems) == 0 {
		t.Fatal("esperaba al menos un problema en el informe")
	}
	if !strings.Contains(h.Problems[0], "roto") {
		t.Fatalf("el problema no menciona el módulo roto: %q", h.Problems[0])
	}
}

// TestPingCuentaLosEnviosDelPump comprueba que los envíos periódicos de un
// módulo se cuentan y se miden, y que el módulo aparece como "ok".
func TestPingCuentaLosEnviosDelPump(t *testing.T) {
	pump := &testModule{name: "periodico"}
	socketPath, _ := startTestServer(t, &pingModule{}, pump)

	// Suscribirse al módulo con un intervalo corto.
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("no se pudo conectar al socket: %v", err)
	}
	defer conn.Close()

	hello := `{"type":"hello","intervals":{"periodico":1}}` + "\n"
	if _, err := conn.Write([]byte(hello)); err != nil {
		t.Fatalf("error enviando hello: %v", err)
	}
	time.Sleep(2500 * time.Millisecond)

	h := pedirPing(t, socketPath)

	var ph ModuleHealth
	for _, m := range h.Modules {
		if m.Name == "periodico" {
			ph = m
		}
	}
	if ph.Sends < 2 {
		t.Fatalf("esperaba varios envíos del módulo, got %d", ph.Sends)
	}
	if ph.Status != ModuleStatusOK {
		t.Fatalf("esperaba ok para el módulo periódico, got %q", ph.Status)
	}
	if ph.Subscribers != 1 {
		t.Fatalf("esperaba 1 suscriptor, got %d", ph.Subscribers)
	}
	if ph.LastSendMS < 0 {
		t.Fatal("esperaba el tiempo desde el último envío")
	}
}

// errPrueba es un error de mentira para el módulo roto.
type errPrueba struct{}

func (errPrueba) Error() string { return "fallo simulado del módulo" }

// TestPingNoSeQuejaDeModulosSinSuscriptores comprueba que un módulo sin
// clientes ni actividad NO se reporta como problema.
//
// Los módulos bajo demanda (files, clipboard) solo trabajan cuando hace
// falta: que estén en reposo es el estado normal, no un fallo. Reportarlo
// sería ruido que esconde los problemas de verdad.
func TestPingNoSeQuejaDeModulosSinSuscriptores(t *testing.T) {
	ocioso := &testModule{name: "bajo-demanda"}
	socketPath, _ := startTestServer(t, &pingModule{}, ocioso)

	h := pedirPing(t, socketPath)

	if len(h.Problems) != 0 {
		t.Fatalf("esperaba ningún problema, got %v", h.Problems)
	}
	if h.Status != HealthStatusOK {
		t.Fatalf("esperaba estado ok, got %q", h.Status)
	}

	var mh ModuleHealth
	for _, m := range h.Modules {
		if m.Name == "bajo-demanda" {
			mh = m
		}
	}
	if mh.Status != ModuleStatusIdle {
		t.Fatalf("esperaba idle, got %q", mh.Status)
	}
	if mh.Subscribers != 0 {
		t.Fatalf("esperaba 0 suscriptores, got %d", mh.Subscribers)
	}
}

// TestPingDetectaUnPumpMuerto comprueba que un módulo periódico suscrito que
// no envía nada se reporta como problema: eso SÍ es un fallo.
func TestPingDetectaUnPumpMuerto(t *testing.T) {
	// Módulo que se suscribe pero cuyo pump no arranca (el pump está muerto).
	periodico := &testModule{name: "periodico", deadPump: true}
	socketPath, _ := startTestServer(t, &pingModule{}, periodico)

	// Suscribirse con un intervalo para que el módulo quede registrado.
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("no se pudo conectar al socket: %v", err)
	}
	defer conn.Close()
	hello := `{"type":"hello","intervals":{"periodico":5}}` + "\n"
	if _, err := conn.Write([]byte(hello)); err != nil {
		t.Fatalf("error enviando hello: %v", err)
	}
	time.Sleep(200 * time.Millisecond)

	h := pedirPing(t, socketPath)
	if h.Status != HealthStatusError && h.Status != HealthStatusDegraded {
		t.Fatalf("esperaba un estado degradado o error, got %q", h.Status)
	}
	if len(h.Problems) == 0 {
		t.Fatal("esperaba un problema por el módulo periódico sin envíos")
	}
	if !strings.Contains(h.Problems[0], "periodico") {
		t.Fatalf("el problema no menciona el módulo: %q", h.Problems[0])
	}
}
