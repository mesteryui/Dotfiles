// Package socket expone el módulo clipboard sobre el socket Unix de shinro.
// Sigue el modelo de Ryoku: historial persistente, deduplicación por hash,
// thumbnails, starred, auto-prune semanal.
package socket

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"

	"shinro-backend/internal/clipboard"
	"shinro-backend/internal/logger"
)

// ClipboardModule gestiona el portapapeles y su historial.
type ClipboardModule struct {
	provider *clipboard.Provider

	broadcastMu sync.RWMutex
	broadcast   func()
}

// NewClipboardModule crea un módulo de portapapeles con el proveedor dado.
func NewClipboardModule(provider *clipboard.Provider) *ClipboardModule {
	module := &ClipboardModule{provider: provider}
	// Cada mutación del historial (incluidas las copias externas que detecta
	// el watcher) empuja el listado a los clientes conectados.
	provider.SetOnChange(module.notifyChanged)
	return module
}

// SetBroadcast registra la función que difunde el estado del módulo a los
// clientes suscritos. La inyecta el servidor al construirse.
func (module *ClipboardModule) SetBroadcast(fn func()) {
	module.broadcastMu.Lock()
	module.broadcast = fn
	module.broadcastMu.Unlock()
}

func (module *ClipboardModule) notifyChanged() {
	module.broadcastMu.RLock()
	fn := module.broadcast
	module.broadcastMu.RUnlock()
	if fn != nil {
		fn()
	}
}

func (module *ClipboardModule) Name() string { return "clipboard" }

func (module *ClipboardModule) HandleHello(cliente *client, raw map[string]json.RawMessage) {
	// Iniciar watch externo (wl-clip-persist + polling de cambios) la primera
	// vez que un cliente se conecta. Es idempotente.
	module.provider.StartWatch()

	// Solo suscribir a quien pida el módulo en el hello (el servicio de
	// portapapeles envía intervals.clipboard, aunque sea 0). Así el resto de
	// conexiones no recibe listados completos en cada copia.
	var payload struct {
		Intervals map[string]int `json:"intervals"`
	}
	if intRaw, ok := raw["intervals"]; ok {
		_ = json.Unmarshal(intRaw, &payload.Intervals)
	}
	if _, ok := payload.Intervals["clipboard"]; !ok {
		return
	}

	// Suscripción sin intervalo periódico: los cambios se empujan en cuanto
	// ocurren (ver notifyChanged), no por tick.
	cliente.setModInterval(module.Name(), 0)
	cliente.setSubscribed(module.Name(), true)
}

// HandleGet atiende una acción del historial.
//
// Devuelve el error si la acción falló, para que el servidor lo anote en el
// informe de salud del módulo. El cliente ya recibe el error por el socket,
// así que aquí no se vuelve a enviar.
func (module *ClipboardModule) HandleGet(cliente *client, raw map[string]json.RawMessage) error {
	var action string
	if a, ok := raw["action"]; ok {
		_ = json.Unmarshal(a, &action)
	}

	// Las acciones que mutan el historial o el portapapeles requieren
	// confirmación explícita del cliente (confirm:true). Evita que una
	// conexión ajena del mismo UID borre, copie o reemplace contenido sin
	// que el usuario lo pida. No es una barrera criptográfica (mismo UID),
	// pero obliga a que la petición sea intencional y se audita.
	var confirm bool
	if c, ok := raw["confirm"]; ok {
		_ = json.Unmarshal(c, &confirm)
	}
	if isMutatingClipboardAction(action) && !confirm {
		err := fmt.Errorf("la acción %s requiere confirmación explícita (confirm:true)", action)
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
	if isMutatingClipboardAction(action) {
		logger.Info("clipboard mutación", "client", cliente.conn.RemoteAddr(), "action", action)
	}

	switch action {
	case "list":
		return module.handleList(cliente)
	case "copy-text":
		return module.handleCopyText(cliente, raw)
	case "copy-image":
		return module.handleCopyImage(cliente, raw)
	case "paste":
		return module.handlePaste(cliente)
	case "delete":
		return module.handleDelete(cliente, raw)
	case "clear":
		return module.handleClear(cliente)
	case "star":
		return module.handleStar(cliente, raw)
	case "stats":
		return module.handleStats(cliente)
	case "get-text":
		return module.handleGetText(cliente, raw)
	case "recopy":
		return module.handleRecopy(cliente, raw)
	case "watch":
		return module.handleWatch(cliente, raw)
	default:
		err := fmt.Errorf("acción desconocida: se espera list, copy-text, copy-image, paste, delete, clear, star, stats, get-text, recopy o watch")
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
}

// handleList envía el historial completo al cliente.
//
// Devuelve false si el mensaje se descartó (cliente saturado), para que quien
// llama pueda reintentarlo: el listado es una instantánea y perderlo dejaría
// al cliente con un historial obsoleto.
func (module *ClipboardModule) handleList(cliente *client) error {
	entries := module.provider.List()
	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "clipboard",
		"data":   entries,
	})
	ok := cliente.write(writeBuf(msg))
	logger.Debug("clipboard list enviado", "client", cliente.conn.RemoteAddr(), "entries", len(entries))
	if !ok {
		return errors.New("no se pudo encolar el listado del portapapeles")
	}
	return nil
}

func (module *ClipboardModule) handleCopyText(cliente *client, raw map[string]json.RawMessage) error {
	var text string
	if t, ok := raw["text"]; ok {
		_ = json.Unmarshal(t, &text)
	}
	if text == "" {
		err := errors.New("texto requerido para copy-text")
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}

	entry, err := module.provider.CopyText(text)
	if err != nil {
		sendErrorToClient(cliente, module.Name(), "error copiando texto al portapapeles: "+err.Error())
		return err
	}

	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "clipboard",
		"data":   entry,
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard copy-text enviado", "client", cliente.conn.RemoteAddr(), "id", entry.ID, "size", entry.Size)
	return nil
}

func (module *ClipboardModule) handleCopyImage(cliente *client, raw map[string]json.RawMessage) error {
	var path string
	if p, ok := raw["path"]; ok {
		_ = json.Unmarshal(p, &path)
	}
	if path == "" {
		err := errors.New("path requerido para copy-image")
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}

	entry, err := module.provider.CopyImage(path)
	if err != nil {
		sendErrorToClient(cliente, module.Name(), "error copiando imagen al portapapeles: "+err.Error())
		return err
	}

	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "clipboard",
		"data":   entry,
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard copy-image enviado", "client", cliente.conn.RemoteAddr(), "path", path, "id", entry.ID)
	return nil
}

func (module *ClipboardModule) handlePaste(cliente *client) error {
	content, err := module.provider.Paste()
	if err != nil {
		sendErrorToClient(cliente, module.Name(), "error pegando del portapapeles: "+err.Error())
		return err
	}

	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "clipboard",
		"data": map[string]any{
			"kind":    "text",
			"mime":    "text/plain;charset=utf-8",
			"size":    len(content),
			"content": content,
		},
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard paste enviado", "client", cliente.conn.RemoteAddr(), "size", len(content))
	return nil
}

func (module *ClipboardModule) handleDelete(cliente *client, raw map[string]json.RawMessage) error {
	var id uint64
	if idRaw, ok := raw["id"]; ok {
		trimmed := strings.TrimSpace(string(idRaw))
		if trimmed == "null" {
			err := errors.New("id inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
		if err := json.Unmarshal(idRaw, &id); err != nil {
			err := errors.New("id inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
	}
	if id == 0 {
		err := errors.New("id requerido para delete")
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
	if err := module.provider.Delete(id); err != nil {
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "clipboard",
		"data":   map[string]any{"deleted": id},
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard delete enviado", "client", cliente.conn.RemoteAddr(), "id", id)
	return nil
}

func (module *ClipboardModule) handleClear(cliente *client) error {
	module.provider.Clear()
	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "clipboard",
		"data":   map[string]any{"cleared": true},
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard clear enviado", "client", cliente.conn.RemoteAddr())
	return nil
}

func (module *ClipboardModule) handleStar(cliente *client, raw map[string]json.RawMessage) error {
	var id uint64
	if idRaw, ok := raw["id"]; ok {
		trimmed := strings.TrimSpace(string(idRaw))
		if trimmed == "null" {
			err := errors.New("id inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
		if err := json.Unmarshal(idRaw, &id); err != nil {
			err := errors.New("id inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
	}

	var starred bool
	if s, ok := raw["starred"]; ok {
		trimmed := strings.TrimSpace(string(s))
		if trimmed == "null" {
			err := errors.New("starred inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
		if err := json.Unmarshal(s, &starred); err != nil {
			err := errors.New("starred inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
	}
	if id == 0 {
		err := errors.New("id requerido para star")
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
	if err := module.provider.Star(id, starred); err != nil {
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "clipboard",
		"data":   map[string]any{"id": id, "starred": starred},
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard star enviado", "client", cliente.conn.RemoteAddr(), "id", id, "starred", starred)
	return nil
}

func (module *ClipboardModule) handleStats(cliente *client) error {
	stats := module.provider.Stats()
	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "clipboard",
		"data":   stats,
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard stats enviado", "client", cliente.conn.RemoteAddr())
	return nil
}

func (module *ClipboardModule) handleGetText(cliente *client, raw map[string]json.RawMessage) error {
	var id uint64
	if idRaw, ok := raw["id"]; ok {
		trimmed := strings.TrimSpace(string(idRaw))
		if trimmed == "null" {
			err := errors.New("id inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
		if err := json.Unmarshal(idRaw, &id); err != nil {
			err := errors.New("id inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
	}
	if id == 0 {
		err := errors.New("id requerido para get-text")
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
	found := module.provider.GetEntry(id)
	if found == nil {
		err := fmt.Errorf("no existe entrada %d", id)
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
	// Para texto: devolver el contenido completo. Para imagen: devolver preview.
	if found.Kind == "text" {
		// Leer payload persistido
		data, err := module.provider.GetContent(found.Hash)
		if err != nil {
			sendErrorToClient(cliente, module.Name(), "no se pudo leer el contenido de la entrada")
			return err
		}
		msg, _ := json.Marshal(map[string]any{
			"type":   "update",
			"module": "clipboard",
			"data": map[string]any{
				"id":      found.ID,
				"kind":    found.Kind,
				"mime":    found.Mime,
				"content": string(data),
				"size":    len(data),
			},
		})
		cliente.write(writeBuf(msg))
	} else {
		msg, _ := json.Marshal(map[string]any{
			"type":   "update",
			"module": "clipboard",
			"data": map[string]any{
				"id":      found.ID,
				"kind":    found.Kind,
				"mime":    found.Mime,
				"preview": found.Preview,
				"size":    found.Size,
			},
		})
		cliente.write(writeBuf(msg))
	}
	logger.Debug("clipboard get-text enviado", "client", cliente.conn.RemoteAddr(), "id", id)
	return nil
}

func (module *ClipboardModule) handleRecopy(cliente *client, raw map[string]json.RawMessage) error {
	var id uint64
	if idRaw, ok := raw["id"]; ok {
		trimmed := strings.TrimSpace(string(idRaw))
		if trimmed == "null" {
			err := errors.New("id inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
		if err := json.Unmarshal(idRaw, &id); err != nil {
			err := errors.New("id inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
	}
	if id == 0 {
		err := errors.New("id requerido para recopy")
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
	if err := module.provider.Recopy(id); err != nil {
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}
	found := module.provider.GetEntry(id)
	msg, _ := json.Marshal(map[string]any{
		"type":   "update",
		"module": "clipboard",
		"data":   found,
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard recopy enviado", "client", cliente.conn.RemoteAddr(), "id", id)
	return nil
}

func (module *ClipboardModule) handleWatch(cliente *client, raw map[string]json.RawMessage) error {
	var enable *bool
	if e, ok := raw["enable"]; ok {
		trimmed := strings.TrimSpace(string(e))
		if trimmed == "null" {
			err := errors.New("enable inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
		var b bool
		if err := json.Unmarshal(e, &b); err != nil {
			err := errors.New("enable inválido")
			sendErrorToClient(cliente, module.Name(), err.Error())
			return err
		}
		enable = &b
	}
	if enable == nil {
		err := errors.New("enable requerido")
		sendErrorToClient(cliente, module.Name(), err.Error())
		return err
	}

	if *enable {
		module.provider.StartWatch()
		msg, _ := json.Marshal(map[string]any{
			"type":   "update",
			"module": "clipboard",
			"data":   map[string]any{"watch": true},
		})
		cliente.write(writeBuf(msg))
		logger.Debug("clipboard watch activado", "client", cliente.conn.RemoteAddr())
	} else {
		module.provider.StopWatch()
		msg, _ := json.Marshal(map[string]any{
			"type":   "update",
			"module": "clipboard",
			"data":   map[string]any{"watch": false},
		})
		cliente.write(writeBuf(msg))
		logger.Debug("clipboard watch desactivado", "client", cliente.conn.RemoteAddr())
	}
	return nil
}

// SendUpdate envía el historial completo al cliente.
//
// Devuelve error si el mensaje no se pudo encolar (cliente saturado), para
// que el servidor pueda reintentarlo.
func (module *ClipboardModule) SendUpdate(cliente *client) error {
	return module.handleList(cliente)
}

func isMutatingClipboardAction(action string) bool {
	switch action {
	case "copy-text", "copy-image", "recopy", "delete", "clear", "star", "watch":
		return true
	}
	return false
}
