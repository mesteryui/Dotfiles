// --- ClipboardService (Singleton) ---
// Historial del portapapeles vía shinro-backend (socket Unix, módulo clipboard).
// Soporta texto e imágenes con historial persistente, deduplicación por hash,
// thumbnails y entradas starred.
//
// Requiere shinro-backend ejecutándose:
//   systemctl --user enable --now shinro-backend
//
// Protocolo: {"type":"get","module":"clipboard","action":...} sobre
// $XDG_RUNTIME_DIR/shinro (una petición por conexión).

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string langWatch: I18nService.language

    onLangWatchChanged: rebuildSnapshot()

    property ListModel entries: ListModel {}
    property var snapshot: []

    property bool ready: false
    readonly property int maxEntries: 100

    property string error: ""
    property bool refreshing: false

    // ── Socket ──────────────────────────────────────────────────
    readonly property string socketPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR");
        if (rt)
            return rt + "/shinro";
        const uid = Quickshell.env("UID");
        return uid ? "/run/user/" + uid + "/shinro" : "";
    }

    Socket {
        id: shinroSocket
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const msg = JSON.parse(data);
                    if (msg.type === "error") {
                        root._handleBackendError(msg.message || "backend");
                        return;
                    }
                    if (msg.type !== "update" || msg.module !== "clipboard")
                        return;
                    root._handleClipboardMsg(msg);
                } catch (e) {
                    console.warn("[ClipboardService] mensaje inválido:", e);
                }
            }
        }

        onConnectionStateChanged: {
            if (!shinroSocket.connected) {
                // No dejar refrescos colgados si el backend desaparece.
                requestTimeout.stop();
                root._pending = [];
                root.refreshing = false;
                root.error = "disconnected";
                return;
            }
            shinroSocket.write(JSON.stringify({
                type: "hello",
                intervals: { clipboard: 0 }
            }) + "\n");
            shinroSocket.flush();
            // Recuperar el historial automáticamente al (re)conectar.
            root.refresh();
        }

        onError: error => {
            // No modificar connected aquí (ver SystemInfoService).
            root._failRequest("socket");
        }
    }

    // Reconexión
    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: true
        running: root.socketPath !== "" && !shinroSocket.connected
        onTriggered: shinroSocket.connected = true
    }

    // Si el backend no responde, liberar el estado en vez de quedarse
    // "refrescando" para siempre.
    Timer {
        id: requestTimeout
        interval: 10000
        repeat: false
        onTriggered: root._failRequest("timeout")
    }

    Component.onCompleted: shinroSocket.connected = true

    // ── Peticiones pendientes (cola FIFO) ───────────────────────
    // El backend responde en orden sobre la misma conexión. Una cola evita
    // que dos peticiones solapadas se pisen (p. ej. refresh + get-text).
    property var _pending: []
    property int pendingId: 0

    function _failRequest(reason) {
        requestTimeout.stop();
        root._pending = [];
        root.refreshing = false;
        root.error = String(reason || "error");
        // No spammear consola en cada reconexión fallida: el backend shinro
        // puede no estar corriendo; el estado `error` ya se expone para la UI.
    }

    // Error devuelto por el backend para UNA petición: consume solo esa
    // entrada de la cola. Las demás siguen vivas y sus respuestas no se
    // atribuyen a la acción equivocada.
    function _handleBackendError(message) {
        if (root._pending.length > 0)
            root._pending.shift();
        if (root._pending.length === 0)
            requestTimeout.stop();
        root.refreshing = false;
        root.error = String(message || "backend");
        // No spammear consola en cada error de backend: el estado `error` ya
        // se expone para la UI.
    }

    function _send(action, extra) {
        if (!shinroSocket.connected) {
            root._failRequest("disconnected");
            return false;
        }
        const payload = { type: "get", module: "clipboard", action: action };
        for (const k in extra)
            payload[k] = extra[k];

        root._pending.push({
            action: action,
            id: extra && extra.id !== undefined ? extra.id : 0
        });
        requestTimeout.restart();
        shinroSocket.write(JSON.stringify(payload) + "\n");
        shinroSocket.flush();
        return true;
    }

    function _handleClipboardMsg(msg) {
        const data = msg.data;
        const head = root._pending.length > 0 ? root._pending[0] : null;
        // Un listado puede llegar sin petición: el backend lo empuja cuando
        // cambia el historial (copia externa, borrado, starred...). No debe
        // consumir la cola; solo las respuestas a un `list` en vuelo se
        // atribuyen a esa petición.
        if (Array.isArray(data) && (!head || head.action !== "list")) {
            root._handleList(data);
            return;
        }
        const req = head;
        if (req)
            root._pending.shift();
        if (root._pending.length === 0)
            requestTimeout.stop();
        if (!req)
            return;

        switch (req.action) {
        case "list":
            root._handleList(data);
            break;
        case "copy-text":
        case "copy-image":
        case "recopy":
        case "paste":
        case "star":
        case "stats":
            break;
        case "delete":
        case "clear":
            root.refresh();
            break;
        case "get-text":
            if (data && data.kind === "text") {
                root.textContent = data.content || "";
                root.textReady(String(data.id !== undefined ? data.id : req.id));
            }
            break;
        }
    }

    // ── Historial ───────────────────────────────────────────────
    function refresh() {
        if (refreshing)
            return;
        if (!shinroSocket.connected) {
            root.error = "disconnected";
            root.refreshing = false;
            return;
        }
        error = "";
        refreshing = true;
        root._send("list", {});
    }

    function _handleList(data) {
        refreshing = false;
        entries.clear();
        if (!Array.isArray(data)) {
            root.ready = true;
            root.rebuildSnapshot();
            return;
        }
        for (let i = 0; i < data.length; i++) {
            const e = data[i];
            const isImg = e.kind === "image";
            const isBin = e.kind === "binary";
            // Etiqueta legible incluso si el preview viene vacío (binarios,
            // texto vacío importado): una fila sin título parece una caja
            // rota.
            let label = e.preview || "";
            if (isImg)
                label = "Imagen";
            else if (isBin)
                label = "Binario";
            else if (label === "")
                label = "Texto";
            entries.append({
                cid: String(e.id),
                text: label,
                raw: "",
                isImage: isImg,
                _backendId: e.id,
                _kind: e.kind,
                _mime: e.mime,
                _size: e.size,
                _w: e.w || 0,
                _h: e.h || 0,
                // El backend serializa la ruta como "thumb" (Entry.ThumbPath).
                _thumbPath: e.thumb || e.thumbPath || "",
                _starred: e.starred || false
            });
        }
        root.ready = true;
        root.rebuildSnapshot();
    }

    function rebuildSnapshot() {
        const out = [];
        for (let i = 0; i < entries.count; i++) {
            const e = entries.get(i);
            out.push({
                cid: e.cid,
                text: e.text,
                raw: e.raw,
                isImage: e.isImage,
                thumb: e._thumbPath || "",
                w: e._w || 0,
                h: e._h || 0,
                size: e._size || 0,
                starred: e._starred === true
            });
        }
        snapshot = out;
    }

    // ── Copiar ──────────────────────────────────────────────────
    function copyEntry(cid, isImage) {
        const id = parseInt(cid, 10);
        if (isNaN(id))
            return;
        root._send("recopy", { id: id });
    }

    function copyText(text) {
        const t = String(text ?? "");
        if (t === "")
            return false;
        root._send("copy-text", { text: t });
        return true;
    }

    // ── Eliminar / limpiar ──────────────────────────────────────
    function deleteEntry(cid) {
        const id = parseInt(cid, 10);
        if (isNaN(id))
            return;
        root._send("delete", { id: id });
    }

    function clear() {
        root._send("clear", {});
    }

    // ── Starred ─────────────────────────────────────────────────
    function star(cid, starred) {
        const id = parseInt(cid, 10);
        if (isNaN(id))
            return;
        root._send("star", { id: id, starred: !!starred });
    }

    // ── Stats ───────────────────────────────────────────────────
    function stats() {
        root._send("stats", {});
    }

    // ── Preview imagen ──────────────────────────────────────────
    property string previewDir: "/tmp/qs-clipboard"

    function previewImage(cid) {
        const id = parseInt(cid, 10);
        if (isNaN(id))
            return "";
        for (let i = 0; i < entries.count; i++) {
            const e = entries.get(i);
            if (e.cid === String(id) && e.isImage && e._thumbPath)
                return e._thumbPath;
        }
        return "";
    }

    // ── Texto completo ──────────────────────────────────────────
    property string textCid: ""
    property string textContent: ""
    property string textAcc: ""
    property string pendingTextId: ""

    signal textReady(string cid)

    function requestText(cid) {
        const id = parseInt(cid, 10);
        if (isNaN(id))
            return "";
        root.pendingId = id;
        root.textCid = String(id);
        root.textContent = "";
        root._send("get-text", { id: id });
        return "";
    }

    // ── Prefetch (API mantenida, sin efecto real en este backend) ─
    property var prefetchQueue: []

    function prefetchNeighbors(cids) {
        root.prefetchQueue = [];
    }

    function clearPrefetch() {
        root.prefetchQueue = [];
    }
}
