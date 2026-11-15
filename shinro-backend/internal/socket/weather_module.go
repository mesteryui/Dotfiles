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

// RequiresInternet implementa OnlineDependentModule.
func (m *weatherModule) RequiresInternet() bool {
	return true
}

// Name implementa Module.
func (m *weatherModule) Name() string { return "weather" }

// HandleHello procesa el handshake del módulo weather y suscribe al cliente al clima.
// La ciudad se recibe de Quickshell (que gestiona la ubicación con PositionSource).
func (m *weatherModule) HandleHello(c *client, raw map[string]json.RawMessage) {
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

	interval := payload.Intervals.Weather
	sub := interval > 0

	c.mu.Lock()
	// Solo se sobrescribe la ciudad si viene una nueva: un hello de
	// reconfiguración sin "location" no debe dejar el clima sin ciudad.
	if payload.Location.City != "" {
		c.city = payload.Location.City
	}
	c.lang = payload.Lang
	if c.lang == "" {
		c.lang = "es"
	}
	city := c.city
	started := c.pumpWthStarted
	c.mu.Unlock()

	c.setModInterval(m.Name(), interval)
	c.setSubscribed(m.Name(), sub)

	logger.Debug("weather handshake",
		"client", c.conn.RemoteAddr(),
		"city", city,
		"interval", interval,
		"subscribed", sub,
	)

	if sub && !started {
		c.pumpWthStarted = true
		c.startPump(m)
	} else if sub && started {
		// Ya iniciado: reconfiguración (nueva ciudad o intervalo) -> despertar para refresco inmediato
		c.signalMod(m.Name())
	}
}

// HandleGet responde a una petición puntual de weather.
func (m *weatherModule) HandleGet(c *client, raw map[string]json.RawMessage) error {
	return m.SendUpdate(c)
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
	if !w.Offline && c.server != nil && c.server.connMon != nil {
		c.server.connMon.ReportSuccess()
	}
	logger.Debug("weather update enviado",
		"client", c.conn.RemoteAddr(),
		"city", w.CityLabel,
		"offline", w.Offline,
		"temp", w.TempC,
	)
	return nil
}

func (m *weatherModule) sendError(c *client, message string) {
	sendErrorToClient(c, m.Name(), message)
}

// InvalidateCaches descarta los datos cacheados del proveedor.
//
// Lo llama el servidor cuando la conectividad vuelve: tras un rato sin red
// lo cacheado puede tener horas, y hay que pedirlo todo otra vez.
//
// Implementa ModuleInvalidator.
func (m *weatherModule) InvalidateCaches() {
	m.wthProvider.InvalidateCaches()
}

// Timings devuelve el desglose del tiempo del último parte: cuánto tardó la
// geocodificación, la previsión, la calidad del aire y los avisos.
//
// Es lo que dice en qué se va el tiempo cuando el módulo va lento.
func (m *weatherModule) Timings() map[string]float64 {
	return m.wthProvider.Timings()
}

// compilo-check de que implementa Module.
var _ Module = (*weatherModule)(nil)
