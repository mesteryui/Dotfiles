// --- FilesService (Singleton) ---
// Búsqueda de archivos en $HOME vía shinro-backend (socket Unix, módulo files).
// El backend devuelve rutas, nombre, tamaño, si es directorio y el tipo MIME
// con su categoría de preview (`kind`: image/text/audio/video/pdf/binary/
// other). La UI decide con `kind` qué preview pintar; no mantiene listas de
// extensiones. No requiere fd.
//
// Requiere shinro-backend ejecutándose:
//   systemctl --user enable --now shinro-backend
//
// Protocolo: {"type":"get","module":"files","action":"search","query":...,"limit":...}
// sobre $XDG_RUNTIME_DIR/shinro (una petición por conexión).

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property ListModel results: ListModel {}

    property bool ready: false
    property bool refreshing: false
    property bool searching: false   // true mientras hay una petición en vuelo al backend
    property string error: ""

    // Señal emitida cuando se han llenado los resultados de una búsqueda.
    // Lleva la query para que los consumidores puedan descartar respuestas
    // obsoletas sin leer data.query del mensaje del socket.
    signal resultsReady(string query)

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
                        // Error del backend para la búsqueda en curso:
                        // liberar el estado en vez de esperar al timeout.
                        requestTimeout.stop();
                        root.searching = false;
                        root.refreshing = false;
                        root.error = msg.message || "backend";
                        return;
                    }
                    if (msg.type !== "update" || msg.module !== "files")
                        return;
                    root._handleFilesMsg(msg);
                } catch (e) {
                    console.warn("[FilesService] mensaje inválido:", e);
                }
            }
        }

        onConnectionStateChanged: {
            if (!shinroSocket.connected) {
                // Backend caído o conexión perdida: no dejar la UI colgada
                // en "buscando..." indefinidamente.
                requestTimeout.stop();
                root.searching = false;
                root.refreshing = false;
                root.error = "disconnected";
                return;
            }
            shinroSocket.write(JSON.stringify({
                                                  type: "hello",
                                                  intervals: {
                                                      files: 0
                                                  }
                                              }) + "\n");
            shinroSocket.flush();
            if (root._pendingSearch)
                root._doSearch();
        }

        onError: error => {
            requestTimeout.stop();
            root.searching = false;
            root.refreshing = false;
            root.error = "socket";
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: true
        running: root.socketPath !== "" && !shinroSocket.connected
        onTriggered: shinroSocket.connected = true
    }

    // Debounce: evita saturar el socket con una petición por tecla.
    // 250 ms tras dejar de teclear.
    Timer {
        id: debounceTimer
        interval: 250
        repeat: false
        onTriggered: root._doSearch()
    }

    // Si el backend no responde (proceso colgado, socket roto), liberar el
    // estado de búsqueda en vez de dejarlo bloqueado para siempre.
    Timer {
        id: requestTimeout
        interval: 8000
        repeat: false
        onTriggered: {
            if (!root.searching)
                return;
            root.searching = false;
            root.refreshing = false;
            root.error = "timeout";
            console.warn("[FilesService] timeout esperando respuesta del backend");
        }
    }

    Component.onCompleted: shinroSocket.connected = true

    // ── Petición ────────────────────────────────────────────────
    property string pendingQuery: ""
    property string lastSentQuery:
        ""   // última query enviada al backend (para descartar respuestas obsoletas)
    property int pendingLimit: 20
    property bool _pendingSearch: false

    function _send(action, extra) {
        const payload = {
            type: "get",
            module: "files",
            action: action
        };
        for (const k in extra)
            payload[k] = extra[k];
        shinroSocket.write(JSON.stringify(payload) + "\n");
        shinroSocket.flush();
    }

    function _handleFilesMsg(msg) {
        const data = msg.data;
        // Descartar respuestas obsoletas: solo aplicar si coinciden con la
        // última query enviada. Esto evita mostrar resultados de una consulta
        // anterior cuando el usuario ya siguió escribiendo.
        if (data && data.query !== undefined && data.query !== root.lastSentQuery)
            return;
        requestTimeout.stop();
        root._pendingSearch = false;
        if (!data || !Array.isArray(data.results)) {
            root.refreshing = false;
            root.searching = false;
            root.ready = true;
            return;
        }
        root.results.clear();
        for (let i = 0; i < data.results.length; i++) {
            const r = data.results[i];
            root.results.append({
                                    path: r.path || "",
                                    name: r.name || "",
                                    size: r.size || 0,
                                    isDir: r.is_dir || false,
                                    // Tipo MIME y categoría de preview que calcula el backend
                                    // (image/text/audio/video/pdf/binary/other). La UI decide
                                    // con `kind`; `mime` es informativo.
                                    mime: r.mime || "",
                                    kind: r.kind || ""
                                });
        }
        root.refreshing = false;
        root.searching = false;
        root.ready = true;
        root.error = "";
        // Notificar que los resultados están listos (con la query para
        // descartar obsoletas en los consumidores).
        root.resultsReady(data.query || "");
    }

    // ── API pública ─────────────────────────────────────────────
    function search(query, limit) {
        root.pendingQuery = query !== undefined && query !== null ? String(query) : "";
        root.pendingLimit = limit !== undefined ? parseInt(limit, 10) : 20;
        if (root.pendingLimit <= 0)
            root.pendingLimit = 20;
        // Debounce: esperar 250 ms tras dejar de teclear antes de enviar
        // al backend, para no saturar el socket con peticiones por tecla.
        if (shinroSocket.connected) {
            debounceTimer.restart();
        } else {
            // Sin backend: no encolar indefinidamente; reintentar al conectar.
            root._pendingSearch = true;
            root.refreshing = false;
            root.searching = false;
            root.error = "disconnected";
        }
    }

    function _doSearch() {
        const q = root.pendingQuery;
        if (q === undefined || q === null) {
            return;
        }
        if (!shinroSocket.connected) {
            root._pendingSearch = true;
            root.refreshing = false;
            root.searching = false;
            root.error = "disconnected";
            return;
        }
        // NO limpiar results aquí: se mantienen los anteriores mientras
        // llega la respuesta del backend, así la UI no parpadea ni se queda
        // vacía durante la búsqueda progresiva (tecla a tecla).
        // Solo limpiaremos cuando llegue la respuesta en _handleFilesMsg.
        root.lastSentQuery = q;
        root._pendingSearch = false;
        root.refreshing = true;
        root.searching = true;
        root.error = "";
        requestTimeout.restart();
        root._send("search", {
                       query: q,
                       limit: root.pendingLimit
                   });
    }

    function clear() {
        debounceTimer.stop();
        requestTimeout.stop();
        root._pendingSearch = false;
        root.results.clear();
        root.refreshing = false;
        root.searching = false;
        root.ready = false;
        root.error = "";
    }
}
