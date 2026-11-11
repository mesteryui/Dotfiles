// Package socket expone el módulo clipboard sobre el socket Unix de shinro.
// Sigue el modelo de Ryoku: historial persistente, deduplicación por hash,
// thumbnails, starred, auto-prune semanal.
package socket

import (
	"encoding/json"
	"fmt"
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

func (module *ClipboardModule) HandleHello(cliente *client, raw map[string]json.RawMessage) (bool, <-chan struct{}) {
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
		return false, nil
	}

	// Suscripción sin intervalo periódico: los cambios se empujan en cuanto
	// ocurren (ver notifyChanged), no por tick.
	cliente.setModInterval(module.Name(), 0)
	cliente.setSubscribed(module.Name(), true)
	return true, nil
}

func (module *ClipboardModule) HandleGet(cliente *client, raw map[string]json.RawMessage) {
	var action string
	if a, ok := raw["action"]; ok {
		_ = json.Unmarshal(a, &action)
	}

	switch action {
	case "list":
		module.handleList(cliente)
	case "copy-text":
		module.handleCopyText(cliente, raw)
	case "copy-image":
		module.handleCopyImage(cliente, raw)
	case "paste":
		module.handlePaste(cliente)
	case "delete":
		module.handleDelete(cliente, raw)
	case "clear":
		module.handleClear(cliente)
	case "star":
		module.handleStar(cliente, raw)
	case "stats":
		module.handleStats(cliente)
	case "get-text":
		module.handleGetText(cliente, raw)
	case "recopy":
		module.handleRecopy(cliente, raw)
	case "watch":
		module.handleWatch(cliente, raw)
	default:
		sendErrorToClient(cliente, module.Name(), "acción desconocida: se espera list, copy-text, copy-image, paste, delete, clear, star, stats, get-text, recopy o watch")
	}
}

func (module *ClipboardModule) handleList(cliente *client) {
	entries := module.provider.List()
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "clipboard",
		"data":   entries,
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard list enviado", "client", cliente.conn.RemoteAddr(), "entries", len(entries))
}

func (module *ClipboardModule) handleCopyText(cliente *client, raw map[string]json.RawMessage) {
	var text string
	if t, ok := raw["text"]; ok {
		_ = json.Unmarshal(t, &text)
	}
	if text == "" {
		sendErrorToClient(cliente, module.Name(), "texto requerido para copy-text")
		return
	}

	entry, err := module.provider.CopyText(text)
	if err != nil {
		sendErrorToClient(cliente, module.Name(), "error copiando texto al portapapeles: "+err.Error())
		return
	}

	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "clipboard",
		"data":   entry,
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard copy-text enviado", "client", cliente.conn.RemoteAddr(), "id", entry.ID, "size", entry.Size)
}

func (module *ClipboardModule) handleCopyImage(cliente *client, raw map[string]json.RawMessage) {
	var path string
	if p, ok := raw["path"]; ok {
		_ = json.Unmarshal(p, &path)
	}
	if path == "" {
		sendErrorToClient(cliente, module.Name(), "path requerido para copy-image")
		return
	}

	entry, err := module.provider.CopyImage(path)
	if err != nil {
		sendErrorToClient(cliente, module.Name(), "error copiando imagen al portapapeles: "+err.Error())
		return
	}

	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "clipboard",
		"data":   entry,
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard copy-image enviado", "client", cliente.conn.RemoteAddr(), "path", path, "id", entry.ID)
}

func (module *ClipboardModule) handlePaste(cliente *client) {
	content, err := module.provider.Paste()
	if err != nil {
		sendErrorToClient(cliente, module.Name(), "error pegando del portapapeles: "+err.Error())
		return
	}

	msg, _ := json.Marshal(map[string]interface{}{
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
}

func (module *ClipboardModule) handleDelete(cliente *client, raw map[string]json.RawMessage) {
	var id uint64
	if idRaw, ok := raw["id"]; ok {
		_ = json.Unmarshal(idRaw, &id)
	}
	if id == 0 {
		sendErrorToClient(cliente, module.Name(), "id requerido para delete")
		return
	}
	if err := module.provider.Delete(id); err != nil {
		sendErrorToClient(cliente, module.Name(), err.Error())
		return
	}
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "clipboard",
		"data":   map[string]any{"deleted": id},
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard delete enviado", "client", cliente.conn.RemoteAddr(), "id", id)
}

func (module *ClipboardModule) handleClear(cliente *client) {
	module.provider.Clear()
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "clipboard",
		"data":   map[string]any{"cleared": true},
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard clear enviado", "client", cliente.conn.RemoteAddr())
}

func (module *ClipboardModule) handleStar(cliente *client, raw map[string]json.RawMessage) {
	var id uint64
	var starred bool
	if idRaw, ok := raw["id"]; ok {
		_ = json.Unmarshal(idRaw, &id)
	}
	if s, ok := raw["starred"]; ok {
		_ = json.Unmarshal(s, &starred)
	}
	if id == 0 {
		sendErrorToClient(cliente, module.Name(), "id requerido para star")
		return
	}
	if err := module.provider.Star(id, starred); err != nil {
		sendErrorToClient(cliente, module.Name(), err.Error())
		return
	}
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "clipboard",
		"data":   map[string]any{"id": id, "starred": starred},
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard star enviado", "client", cliente.conn.RemoteAddr(), "id", id, "starred", starred)
}

func (module *ClipboardModule) handleStats(cliente *client) {
	stats := module.provider.Stats()
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "clipboard",
		"data":   stats,
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard stats enviado", "client", cliente.conn.RemoteAddr())
}

func (module *ClipboardModule) handleGetText(cliente *client, raw map[string]json.RawMessage) {
	var id uint64
	if idRaw, ok := raw["id"]; ok {
		_ = json.Unmarshal(idRaw, &id)
	}
	if id == 0 {
		sendErrorToClient(cliente, module.Name(), "id requerido para get-text")
		return
	}
	found := module.provider.GetEntry(id)
	if found == nil {
		sendErrorToClient(cliente, module.Name(), "no existe entrada "+fmt.Sprintf("%d", id))
		return
	}
	// Para texto: devolver el contenido completo. Para imagen: devolver preview.
	if found.Kind == "text" {
		// Leer payload persistido
		data, err := module.provider.GetContent(found.Hash)
		if err != nil {
			sendErrorToClient(cliente, module.Name(), "no se pudo leer el contenido de la entrada")
			return
		}
		msg, _ := json.Marshal(map[string]interface{}{
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
		msg, _ := json.Marshal(map[string]interface{}{
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
}

func (module *ClipboardModule) handleRecopy(cliente *client, raw map[string]json.RawMessage) {
	var id uint64
	if idRaw, ok := raw["id"]; ok {
		_ = json.Unmarshal(idRaw, &id)
	}
	if id == 0 {
		sendErrorToClient(cliente, module.Name(), "id requerido para recopy")
		return
	}
	if err := module.provider.Recopy(id); err != nil {
		sendErrorToClient(cliente, module.Name(), err.Error())
		return
	}
	found := module.provider.GetEntry(id)
	msg, _ := json.Marshal(map[string]interface{}{
		"type":   "update",
		"module": "clipboard",
		"data":   found,
	})
	cliente.write(writeBuf(msg))
	logger.Debug("clipboard recopy enviado", "client", cliente.conn.RemoteAddr(), "id", id)
}

func (module *ClipboardModule) handleWatch(cliente *client, raw map[string]json.RawMessage) {
	var enable bool
	if e, ok := raw["enable"]; ok {
		_ = json.Unmarshal(e, &enable)
	}
	if enable {
		module.provider.StartWatch()
		msg, _ := json.Marshal(map[string]interface{}{
			"type":   "update",
			"module": "clipboard",
			"data":   map[string]any{"watch": true},
		})
		cliente.write(writeBuf(msg))
		logger.Debug("clipboard watch activado", "client", cliente.conn.RemoteAddr())
	} else {
		module.provider.StopWatch()
		msg, _ := json.Marshal(map[string]interface{}{
			"type":   "update",
			"module": "clipboard",
			"data":   map[string]any{"watch": false},
		})
		cliente.write(writeBuf(msg))
		logger.Debug("clipboard watch desactivado", "client", cliente.conn.RemoteAddr())
	}
}

// Pump es un no-op para clipboard: los cambios se empujan por eventos,
// no por un pump periódico.
func (module *ClipboardModule) Pump(cliente *client, wake <-chan struct{}, done <-chan struct{}) {
}

// SendUpdate envía el historial completo al cliente.
func (module *ClipboardModule) SendUpdate(cliente *client) error {
	module.handleList(cliente)
	return nil
}

// compilo-check de que implementa Module.
var _ Module = (*ClipboardModule)(nil)
