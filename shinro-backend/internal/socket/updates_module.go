package socket

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"time"

	"shinro-backend/internal/logger"
	"shinro-backend/internal/safe"
	"shinro-backend/internal/updates"
)

// updatesModule expone el módulo de actualizaciones por el socket.
//
// El cliente pide `get` para ver el estado actual, `check` para comprobar y
// `update` ya NO se ejecuta aquí: por seguridad, la actualización se hace en
// un terminal interactivo con el script que devuelve `update_script`. El
// backend solo comprueba (read-only) y expone el comando a ejecutar.
type updatesModule struct {
	provider *updates.Module

	mu        sync.Mutex
	lastCheck time.Time
}

// NewUpdatesModule crea el módulo de socket sobre el proveedor de updates.
func NewUpdatesModule(provider *updates.Module) *updatesModule {
	return &updatesModule{provider: provider}
}

func (m *updatesModule) Name() string { return "updates" }

// RequiresInternet implementa OnlineDependentModule: al recuperar la red el
// servidor despierta el pump y se vuelve a comprobar sin esperar al tick.
func (m *updatesModule) RequiresInternet() bool { return true }

func (m *updatesModule) HandleHello(c *client, raw map[string]json.RawMessage) {
	// `intervals` llega como objeto libre: hay que distinguir "no habla de
	// updates" de "updates: 0" (que sí desactiva la suscripción).
	var intervals map[string]json.RawMessage
	if intRaw, ok := raw["intervals"]; ok {
		if err := json.Unmarshal(intRaw, &intervals); err != nil {
			logger.Debug("updates: intervals inválido", "error", err)
		}
	}
	intervalRaw, hasInterval := intervals["updates"]
	updRaw, hasUpdates := raw["updates"]

	// Otros clientes (system, weather) mandan hello sin mencionar updates.
	// No deben reconfigurar el proveedor global ni tocar esta suscripción.
	if !hasInterval && !hasUpdates {
		return
	}

	var interval int
	if hasInterval {
		if err := json.Unmarshal(intervalRaw, &interval); err != nil {
			logger.Debug("updates: interval inválido", "error", err)
		}
	}

	var payload struct {
		Backends []string `json:"backends"`
		// Command y Update se ignoran deliberadamente: vienen del cliente
		// (socket Unix) y permitirían ejecutar comandos arbitrarios con los
		// privilegios del daemon. Solo se aceptan los backends detectados.
	}
	if hasUpdates {
		if err := json.Unmarshal(updRaw, &payload); err != nil {
			logger.Debug("updates: payload inválido", "error", err)
		} else {
			m.provider.Configure(updates.Config{
				Backends: payload.Backends,
			})
			// avoid duplicate configure below
			hasUpdates = false
		}
	}

	// Mínimo 300 s (5 min); 0 desactiva la comprobación periódica.
	if interval > 0 && interval < 300 {
		interval = 300
	}
	if interval > 86400 {
		interval = 86400
	}
	if interval < 0 {
		interval = 0
	}
	sub := interval > 0

	// El proveedor solo necesita la configuración de backends/comandos: el
	// intervalo es por cliente. Un hello que solo cambia el intervalo no
	// debe resetear el estado compartido. La configuración ya se aplicó arriba
	// si el payload era válido.

	c.setModInterval(m.Name(), interval)
	c.setSubscribed(m.Name(), sub)

	c.mu.Lock()
	started := c.pumpUpdStarted
	if sub && !started {
		c.pumpUpdStarted = true
		c.mu.Unlock()
		logger.Debug("updates handshake",
			"client", c.conn.RemoteAddr(),
			"interval", interval,
			"subscribed", sub,
			"backends", payload.Backends,
		)
		c.startPump(m)
		return
	}
	c.mu.Unlock()

	logger.Debug("updates handshake",
		"client", c.conn.RemoteAddr(),
		"interval", interval,
		"subscribed", sub,
		"backends", payload.Backends,
	)

	if sub && started {
		// Reconfiguración: despertar para aplicar el nuevo intervalo y
		// comprobar de inmediato.
		c.signalMod(m.Name())
	}
}

func (m *updatesModule) HandleGet(c *client, raw map[string]json.RawMessage) error {
	var action string
	if a, ok := raw["action"]; ok {
		_ = json.Unmarshal(a, &action)
	}

	switch action {
	case "", "get":
		return m.SendSnapshot(c)

	case "check":
		m.mu.Lock()
		now := time.Now()
		if now.Sub(m.lastCheck) < 15*time.Second {
			m.mu.Unlock()
			return m.SendSnapshot(c)
		}
		m.lastCheck = now
		m.mu.Unlock()
		// Asíncrono: la comprobación puede tardar (checkupdates descarga
		// bases de datos). El cliente suscrito recibe el progreso por
		// broadcast; el que preguntó recibe el resultado final aquí.
		safe.Go("socket.updates.check", func() {
			m.provider.Check(context.Background())
			_ = m.SendSnapshot(c)
		})
		return nil

	case "update":
		// Por seguridad, el backend NO ejecuta actualizaciones: las lanza el
		// propio cliente (CLI o shell) en un terminal interactivo, usando el
		// script de `update_script`. Se devuelve el estado actual con el
		// comando a ejecutar.
		err := errors.New("la actualización debe ejecutarse en un terminal interactivo usando update_script")
		sendErrorToClient(c, m.Name(), err.Error())
		return err

	default:
		sendErrorToClient(c, m.Name(), "acción desconocida: se espera get, check o update")
		return fmt.Errorf("acción desconocida: %s", action)
	}
}

// SendUpdate ejecuta una comprobación (si hay red) y envía el estado. Es lo
// que llama el pump periódico y el refresco al recuperar la conectividad.
func (m *updatesModule) SendUpdate(c *client) error {
	m.provider.Check(context.Background())
	return m.SendSnapshot(c)
}

// SendSnapshot envía el estado actual sin comprobar. Se usa para el broadcast
// de progreso y para responder a `get`.
func (m *updatesModule) SendSnapshot(c *client) error {
	state := m.provider.Snapshot()
	msg, err := json.Marshal(map[string]any{
		"type":   "update",
		"module": "updates",
		"data":   state,
	})
	if err != nil {
		return err
	}
	if !c.write(writeBuf(msg)) {
		return errors.New("cliente no disponible")
	}
	return nil
}

func (m *updatesModule) InvalidateCaches() {
	m.provider.InvalidateCaches()
}

var (
	_ Module                = (*updatesModule)(nil)
	_ OnlineDependentModule = (*updatesModule)(nil)
	_ ModuleInvalidator     = (*updatesModule)(nil)
)

// snapshotSender lo implementan los módulos que pueden enviar su estado sin
// volver a calcularlo (broadcast de progreso).
type snapshotSender interface {
	SendSnapshot(c *client) error
}
