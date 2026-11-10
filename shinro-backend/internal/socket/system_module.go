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
func (m *systemModule) HandleHello(c *client, raw map[string]json.RawMessage) (bool, <-chan struct{}) {
	var payload struct {
		Intervals struct {
			System int `json:"system"`
		} `json:"intervals"`
	}
	if intRaw, ok := raw["intervals"]; ok {
		_ = json.Unmarshal(intRaw, &payload.Intervals)
	}

	c.mu.Lock()
	c.intSys = payload.Intervals.System
	sub := c.intSys > 0
	c.subSys = sub
	if c.subs == nil {
		c.subs = make(map[string]bool)
	}
	c.subs["system"] = sub
	if c.modIntervals == nil {
		c.modIntervals = make(map[string]int)
	}
	c.modIntervals["system"] = c.intSys
	started := c.pumpSysStarted
	c.mu.Unlock()

	logger.Debug("system handshake", "client", c.conn.RemoteAddr(), "interval", c.intSys, "subscribed", sub)

	if sub && !started {
		c.pumpSysStarted = true
		go pumpModule(m, c, c.done)
	}
	return sub, nil
}

// HandleGet responde a una petición puntual de system.
func (m *systemModule) HandleGet(c *client, raw map[string]json.RawMessage) {
	m.SendUpdate(c)
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

// Pump ejecuta el bucle periódico de system. Se usa a través de pumpModule.
func (m *systemModule) Pump(c *client, wake <-chan struct{}, done <-chan struct{}) {
	pumpModule(m, c, done)
}

func (m *systemModule) sendError(c *client, message string) {
	sendErrorToClient(c, m.Name(), message)
}

// compilo-check de que implementa Module.
var _ Module = (*systemModule)(nil)
