package socket

import (
	"encoding/json"
	"net"
	"sync"
	"testing"
	"time"
)

// TestElEstadoDeLosClientesSeLiberaAlDesconectar comprueba que el módulo de
// archivos no guarda estado de clientes que ya se han ido.
//
// Sin la limpieza, el mapa de consultas guardaría una entrada por cada
// cliente que hubiera buscado alguna vez: una fuga lenta pero real en un
// daemon que vive días.
func TestElEstadoDeLosClientesSeLiberaAlDesconectar(t *testing.T) {
	files := &filesModuleForTest{}
	socketPath, _ := startTestServer(t, &pingModule{}, files)

	// Un cliente busca algo y se desconecta.
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		t.Fatalf("no se pudo conectar al socket: %v", err)
	}
	get := `{"type":"get","module":"files","action":"search","query":"x","limit":5}` + "\n"
	if _, err := conn.Write([]byte(get)); err != nil {
		t.Fatalf("error enviando la búsqueda: %v", err)
	}
	time.Sleep(200 * time.Millisecond)
	conn.Close()

	// Dar tiempo a que el servidor detecte la desconexión.
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		files.mu.Lock()
		n := len(files.queries)
		files.mu.Unlock()
		if n == 0 {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}

	files.mu.Lock()
	n := len(files.queries)
	files.mu.Unlock()
	t.Fatalf("quedaron %d entradas de clientes que ya se fueron", n)
}

// filesModuleForTest es un módulo mínimo que guarda estado por cliente, como
// el de archivos.
type filesModuleForTest struct {
	mu      sync.Mutex
	queries map[*client]bool
}

func (m *filesModuleForTest) Name() string                                          { return "files" }
func (m *filesModuleForTest) HandleHello(c *client, raw map[string]json.RawMessage) {}
func (m *filesModuleForTest) HandleGet(c *client, raw map[string]json.RawMessage) error {
	m.mu.Lock()
	if m.queries == nil {
		m.queries = make(map[*client]bool)
	}
	m.queries[c] = true
	m.mu.Unlock()
	return nil
}
func (m *filesModuleForTest) SendUpdate(c *client) error { return nil }

// ClientGone suelta el estado del cliente que se ha ido.
func (m *filesModuleForTest) ClientGone(c *client) {
	m.mu.Lock()
	delete(m.queries, c)
	m.mu.Unlock()
}
