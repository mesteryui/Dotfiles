package socket

import (
	"encoding/json"
	"sync"
)

// pingModule expone un endpoint de salud (health check) para que la shell
// pueda comprobar que el backend responde sin depender de system o weather.
//
// Además de confirmar que el daemon está vivo, devuelve el informe de salud
// completo: el estado de cada módulo (último envío, errores, cuánto tardan),
// los datos del daemon (uptime, goroutines, memoria, clientes) y la lista de
// problemas y de cosas que se podrían mejorar.
//
// Es la forma de saber qué está pasando por dentro sin tener que leer el log.
type pingModule struct {
	healthMu sync.RWMutex
	healthFn func(c *client) Health
}

// SetHealthProvider registra la función que construye el informe de salud.
//
// Lo inyecta el servidor al construirse (igual que el portapapeles recibe su
// broadcast), de modo que este módulo no necesita conocer al servidor.
func (m *pingModule) SetHealthProvider(fn func(c *client) Health) {
	m.healthMu.Lock()
	m.healthFn = fn
	m.healthMu.Unlock()
}

// Name implementa Module.
func (m *pingModule) Name() string { return "ping" }

// HandleHello no se suscribe a actualizaciones periódicas.
func (m *pingModule) HandleHello(c *client, raw map[string]json.RawMessage) {
}

// HandleGet responde a una petición puntual de ping.
func (m *pingModule) HandleGet(c *client, raw map[string]json.RawMessage) error {
	return m.SendUpdate(c)
}

// SendUpdate envía el informe de salud al cliente.
func (m *pingModule) SendUpdate(c *client) error {
	m.healthMu.RLock()
	fn := m.healthFn
	m.healthMu.RUnlock()

	data := Health{OK: "true", Status: HealthStatusOK}
	if fn != nil {
		data = fn(c)
	}

	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "ping",
		"data":   data,
	})
	c.write(writeBuf(msg))
	return nil
}

// compilo-check de que implementa Module.
var _ Module = (*pingModule)(nil)
