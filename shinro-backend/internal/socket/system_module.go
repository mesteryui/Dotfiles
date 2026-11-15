package socket

import (
	"encoding/json"

	"shinro-backend/internal/logger"
	"shinro-backend/internal/system"
)

// systemModule expone métricas de sistema (RAM, CPU, swap, disco, temperatura).
type systemModule struct {
	sysProvider *system.Provider
}

// Name implementa Module.
func (m *systemModule) Name() string { return "system" }

// HandleHello procesa el handshake del módulo system.
func (m *systemModule) HandleHello(c *client, raw map[string]json.RawMessage) {
	var payload struct {
		Intervals struct {
			System int `json:"system"`
		} `json:"intervals"`
	}
	if intRaw, ok := raw["intervals"]; ok {
		_ = json.Unmarshal(intRaw, &payload.Intervals)
	}

	interval := payload.Intervals.System
	sub := interval > 0

	c.setModInterval(m.Name(), interval)
	c.setSubscribed(m.Name(), sub)

	c.mu.Lock()
	started := c.pumpSysStarted
	c.mu.Unlock()

	logger.Debug("system handshake", "client", c.conn.RemoteAddr(), "interval", interval, "subscribed", sub)

	if sub && !started {
		c.pumpSysStarted = true
		c.startPump(m)
	} else if sub && started {
		c.signalMod(m.Name())
	}
}

// HandleGet responde a una petición puntual de system.
func (m *systemModule) HandleGet(c *client, raw map[string]json.RawMessage) error {
	return m.SendUpdate(c)
}

// SendUpdate envía las métricas de sistema al cliente.
func (m *systemModule) SendUpdate(c *client) error {
	stats, err := m.sysProvider.Stats()
	if err != nil {
		m.sendError(c, "error leyendo system: "+err.Error())
		return err
	}
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "system",
		"data":   stats,
	})
	c.write(writeBuf(msg))
	logger.Debug("system update enviado", "client", c.conn.RemoteAddr(), "cpu", stats.CPUPercent, "ram", stats.RAMPercent)
	return nil
}

func (m *systemModule) sendError(c *client, message string) {
	sendErrorToClient(c, m.Name(), message)
}

// compilo-check de que implementa Module.
var _ Module = (*systemModule)(nil)
