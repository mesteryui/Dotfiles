package socket

import (
	"encoding/json"
)

// pingModule expone un endpoint de salud (health check) para que la shell
// pueda comprobar que el backend responde sin depender de system o weather.
type pingModule struct{}

// Name implementa Module.
func (m *pingModule) Name() string { return "ping" }

// HandleHello no se suscribe a actualizaciones periódicas.
func (m *pingModule) HandleHello(c *client, raw map[string]json.RawMessage) (bool, <-chan struct{}) {
	return false, nil
}

// HandleGet responde a una petición puntual de ping.
func (m *pingModule) HandleGet(c *client, raw map[string]json.RawMessage) {
	m.SendUpdate(c)
}

// SendUpdate envía una respuesta de salud al cliente.
func (m *pingModule) SendUpdate(c *client) error {
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "ping",
		"data":   map[string]string{"ok": "true"},
	})
	c.write(writeBuf(msg))
	return nil
}

// Pump no hace nada: ping no tiene actualizaciones periódicas.
func (m *pingModule) Pump(c *client, wake <-chan struct{}, done <-chan struct{}) {}

func (m *pingModule) sendError(c *client, message string) {
	sendErrorToClient(c, m.Name(), message)
}

// compilo-check de que implementa Module.
var _ Module = (*pingModule)(nil)
