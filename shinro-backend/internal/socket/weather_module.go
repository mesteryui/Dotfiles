package socket

import (
	"encoding/json"

	"shinro-backend/internal/logger"
	"shinro-backend/internal/weather"
)

// weatherModule expone el parte del clima (Open-Meteo, AQI, avisos MeteoAlarm).
type weatherModule struct {
	wthProvider *weather.Provider
}

// Name implementa Module.
func (m *weatherModule) Name() string { return "weather" }

// HandleHello procesa el handshake del módulo weather y suscribe al cliente al clima.
// La ciudad se recibe de Quickshell (que gestiona la ubicación con PositionSource).
func (m *weatherModule) HandleHello(c *client, raw map[string]json.RawMessage) (bool, <-chan struct{}) {
	var payload struct {
		Location struct {
			City string `json:"city"`
		} `json:"location"`
		Intervals struct {
			Weather int `json:"weather"`
		} `json:"intervals"`
		Lang string `json:"lang"`
	}
	if locRaw, ok := raw["location"]; ok {
		_ = json.Unmarshal(locRaw, &payload.Location)
	}
	if intRaw, ok := raw["intervals"]; ok {
		_ = json.Unmarshal(intRaw, &payload.Intervals)
	}

	c.mu.Lock()
	c.city = payload.Location.City
	c.lang = payload.Lang
	if c.lang == "" {
		c.lang = "es"
	}
	c.intWth = payload.Intervals.Weather
	sub := c.intWth > 0
	c.subWth = sub
	if c.subs == nil {
		c.subs = make(map[string]bool)
	}
	c.subs["weather"] = sub
	if c.modIntervals == nil {
		c.modIntervals = make(map[string]int)
	}
	c.modIntervals["weather"] = c.intWth
	started := c.pumpWthStarted
	c.mu.Unlock()

	logger.Debug("weather handshake",
		"client", c.conn.RemoteAddr(),
		"city", c.city,
		"interval", c.intWth,
		"subscribed", sub,
	)

	if sub && !started {
		c.pumpWthStarted = true
		go pumpModule(m, c, c.done)
	}

	return sub, nil
}

// HandleGet responde a una petición puntual de weather.
func (m *weatherModule) HandleGet(c *client, raw map[string]json.RawMessage) {
	m.SendUpdate(c)
}

// SendUpdate envía el parte del clima al cliente.
func (m *weatherModule) SendUpdate(c *client) error {
	c.mu.Lock()
	city := c.city
	lang := c.lang
	c.mu.Unlock()
	if lang == "" {
		lang = "es"
	}

	w, err := m.wthProvider.Snapshot(city, lang)
	if err != nil {
		m.sendError(c, "error leyendo weather: "+err.Error())
		return err
	}

	if city != "" {
		if w.City == "" {
			w.City = city
		}
		if w.CityLabel == "" {
			w.CityLabel = city
		}
	}

	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "weather",
		"data":   w,
	})
	c.write(writeBuf(msg))
	logger.Debug("weather update enviado",
		"client", c.conn.RemoteAddr(),
		"city", w.CityLabel,
		"offline", w.Offline,
		"temp", w.TempC,
	)
	return nil
}

// Pump ejecuta el bucle periódico de weather. Se usa a través de pumpModule.
func (m *weatherModule) Pump(c *client, wake <-chan struct{}, done <-chan struct{}) {
	pumpModule(m, c, done)
}

func (m *weatherModule) sendError(c *client, message string) {
	sendErrorToClient(c, m.Name(), message)
}

// compilo-check de que implementa Module.
var _ Module = (*weatherModule)(nil)
