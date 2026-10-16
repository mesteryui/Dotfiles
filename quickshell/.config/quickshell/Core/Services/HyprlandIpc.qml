pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

/**
 * HyprlandIpc
 * -----------
 * Envía órdenes a Hyprland SIN crear ningún proceso (sin `hyprctl`,
 * sin QProcess/Process). Escribe directamente en el socket IPC de
 * Hyprland (`.socket.sock`), que es exactamente lo que `hyprctl`
 * hace por dentro:
 *
 *   hyprctl/src/main.cpp `request()`: socket(AF_UNIX, SOCK_STREAM),
 *   connect($XDG_RUNTIME_DIR/hypr/$HIS/.socket.sock),
 *   write(cmd), read() hasta EOF, close().
 *
 * Referencias:
 *   - Wiki IPC: https://wiki.hypr.land/IPC/
 *   - Comandos: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Using-hyprctl/
 *   - Quickshell Hyprland.requestSocketPath + dispatch():
 *       https://quickshell.org/docs/v0.2.0/types/Quickshell.Hyprland/Hyprland/
 *   - Quickshell.Io.Socket (path/connected/write/flush):
 *       https://quickshell.org/docs/v0.2.0/types/Quickshell.Io/Socket/
 *   - Fuente Quickshell src/wayland/hyprland/ipc/connection.cpp
 *     `makeRequest()`: crea un QLocalSocket NUEVO por petición,
 *     escribe, lee con readyRead y lo destruye. Este helper replica
 *     ese patrón en QML con cola FIFO.
 *
 * Por qué no basta con `Hyprland.dispatch()`:
 *   El singleton QML de Quickshell solo expone `dispatch(request)`,
 *   que internamente hace `makeRequest("dispatch/" + request)`.
 *   Sirve para dispatchers (`Hyprland.dispatch("exec kitty")`) pero
 *   NO puede enviar `eval ...`, `reload`, `j/...` ni `[[BATCH]]...`.
 *   Para eso hace falta el socket crudo, que es lo que este
 *   helper ofrece.
 *
 * Detalles de protocolo verificados en Hyprland 0.56.2:
 *   - Path: Hyprland.requestSocketPath
 *     ($XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock)
 *   - Bytes: comando en crudo SIN newline, p.ej. `eval hl.config({...})`,
 *     `reload`, `dispatch exec kitty`. Sin `/` inicial (el servidor
 *     acepta verbatim sin flags; `hyprctl` antepone `/` cuando no hay
 *     flags, ambas formas valen).
 *   - Respuesta: texto plano hasta que Hyprland CIERRA la conexión.
 *     `eval`/`reload` responden `ok` SIN `\n` final (verificado con
 *     socket python: repr(b'ok')). Por eso el parser usa
 *     `splitMarker: ""` (chunks arbitrarios) en vez del `\n` por
 *     defecto, que jamás emitiría `read` para `ok`.
 *   - Hyprland evalúa conexiones de forma SÍNCRONA: una conexión
 *     sin cerrar congela el compositor hasta el timeout de 5s
 *     (wiki IPC). Patrón obligatorio: conectar → write → flush →
 *     leer → connected=false INMEDIATAMENTE. Este helper nunca
 *     mantiene la conexión en idle.
 *   - En Hyprland con parser Lua (0.56.x) `keyword` YA NO funciona:
 *     responde "keyword can't work with non-legacy parsers. Use eval."
 *     Hay que usar `eval hl.config({...})`. Verificado por socket.
 *
 * Uso:
 *   HyprlandIpc.send("reload")
 *   HyprlandIpc.evalLua("hl.config({ animations = { enabled = false } })")
 *   HyprlandIpc.send("dispatch exec kitty")  // o Hyprland.dispatch(...)
 *   HyprlandIpc.send("j/clients")            // respuesta JSON en replyReceived
 */
Singleton {
    id: root

    /// Cola FIFO de comandos pendientes (strings ya formateados wire).
    property var queue: []
    /// Comando actualmente en vuelo ("" si idle).
    property string currentCommand: ""
    /// Buffer acumulado de la respuesta en curso.
    property string buffer: ""
    /// true mientras hay una petición en vuelo.
    readonly property bool busy: root.currentCommand !== ""
    /// Número de comandos en espera (sin contar el actual).
    readonly property int pendingCount: root.queue.length
    /// Último error reportado por el socket (informativo).
    property string lastError: ""

    /// Se emite cuando Hyprland responde (normalmente "ok").
    signal replyReceived(command: string, reply: string)
    /// Se emite si la petición falla (socket ausente, error, timeout).
    signal requestFailed(command: string, reason: string)

    /**
     * Encola un comando IPC crudo. Ejemplos:
     *   "reload" | "eval <lua>" | "dispatch <args>" | "j/monitors"
     * No crea ningún proceso; escribe al socket de Hyprland.
     */
    function send(command: string): void {
        if (!command || command.length === 0) {
            console.warn("[HyprlandIpc] send() ignorado: comando vacío.");
            return;
        }
        root.queue.push(command);
        root.pump();
    }

    /// Azúcar para `send("eval " + luaCode)`.
    function evalLua(luaCode: string): void {
        root.send("eval " + luaCode);
    }

    /// Intenta avanzar la cola: si idle y hay pendientes, conecta.
    function pump(): void {
        if (root.currentCommand !== "")
            return; // hay petición en vuelo, onRead/onDisconnected la completará
        if (sock.connected)
            return; // conectando o conectado, onConnectedChanged escribirá
        if (root.queue.length === 0)
            return;
        if (Hyprland.requestSocketPath === "") {
            const cmd = root.queue.shift();
            console.warn("[HyprlandIpc] sin requestSocketPath (¿Hyprland caído?), descarto:", cmd);
            root.requestFailed(cmd, "no requestSocketPath");
            if (root.queue.length > 0)
                Qt.callLater(root.pump);
            return;
        }
        // Fijar path en cada intento por si la instancia cambió.
        sock.path = Hyprland.requestSocketPath;
        root.buffer = "";
        // Limpiar el error anterior: si esta petición falla, el watchdog
        // debe mostrar SU motivo, no uno rancio de un fallo previo.
        root.lastError = "";
        // `connected = true` es petición asíncrona: el write real
        // ocurre en onConnectedChanged, como manda la doc de Socket.
        sock.connected = true;
        // Paracaídas: si Hyprland no responde, no dejar la conexión
        // colgada (congelaría el compositor hasta 5s). Ver watchdog.
        watchdog.restart();
    }

    /// Cierra la conexión y programa el siguiente comando de la cola.
    /// NOTA de reentrancia: NUNCA tocar `sock.connected` de forma
    /// síncrona desde onError/onConnectedChanged (crashea Quickshell:
    /// QObject::disconnect nullptr + deleteLater en plena emisión del
    /// QLocalSocket, ver stack QAbstractSocketPrivate::setErrorAndEmit).
    /// La desconexión siempre se difiere con Qt.callLater; Hyprland ya
    /// cerró su lado, así que no hay riesgo de congelar el compositor.
    function disconnectSoon(): void {
        Qt.callLater(function () {
            if (sock.connected)
                sock.connected = false;
        });
    }

    function finishOk(): void {
        watchdog.stop();
        const cmd = root.currentCommand;
        const reply = root.buffer;
        root.currentCommand = "";
        root.buffer = "";
        root.disconnectSoon();
        if (cmd !== "")
            root.replyReceived(cmd, reply);
        if (root.queue.length > 0)
            Qt.callLater(root.pump);
    }

    function finishErr(reason: string): void {
        watchdog.stop();
        const cmd = root.currentCommand !== "" ? root.currentCommand : (root.queue.length > 0 ? root.queue.shift() : "");
        root.currentCommand = "";
        root.buffer = "";
        root.disconnectSoon();
        if (cmd !== "") {
            console.warn("[HyprlandIpc] petición fallida:", cmd, "→", reason);
            root.requestFailed(cmd, reason);
        }
        if (root.queue.length > 0)
            Qt.callLater(root.pump);
    }

    // Si no hay respuesta en 2s, aborta: mejor un error visible que
    // una conexión semiabierta que bloquee a Hyprland (timeout 5s).
    // Cubre también el fallo de conexión (p.ej. socket ausente):
    // en ese caso nunca hay onConnectedChanged(false), así que el
    // item encolado se reporta como fallo aquí.
    Timer {
        id: watchdog
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.currentCommand !== "")
                root.finishErr("timeout 2s sin respuesta");
            else if (root.queue.length > 0)
                root.finishErr("sin conexión a Hyprland" + (root.lastError !== "" ? ": " + root.lastError : ""));
            else if (sock.connected)
                sock.connected = false;
        }
    }

    Socket {
        id: sock

        // path se fija en pump() desde Hyprland.requestSocketPath.
        // No se hardcodea $XDG_RUNTIME_DIR/$HIS: Quickshell ya lo resuelve.
        parser: SplitParser {
            // "" = chunks arbitrarios, sin esperar `\n`.
            // Imprescindible: `eval`/`reload` responden `ok` sin newline.
            splitMarker: ""
            onRead: data => {
                root.buffer += data;
            }
        }

        onConnectedChanged: {
            if (connected) {
                // Conexión lista: enviar el siguiente comando.
                if (root.currentCommand !== "")
                    return; // ya enviado, esperando respuesta
                if (root.queue.length === 0) {
                    // Conexión espuria sin trabajo: cerrar al instante
                    // para no congelar a Hyprland (diferido: ver nota
                    // de reentrancia en disconnectSoon).
                    root.disconnectSoon();
                    return;
                }
                root.currentCommand = root.queue.shift();
                root.buffer = "";
                sock.write(root.currentCommand);
                sock.flush();
                watchdog.restart();
            } else {
                // Desconexión = fin de respuesta (Hyprland cierra tras
                // responder). Si hay comando en vuelo, completarlo.
                // Respuesta vacía = anómalo (`eval`/`reload` siempre
                // responden `ok`): reportarlo como fallo visible.
                if (root.currentCommand !== "") {
                    if (root.buffer !== "")
                        root.finishOk();
                    else
                        root.finishErr("respuesta vacía (peer cerró sin datos)" + (root.lastError !== "" ? ": " + root.lastError : ""));
                }
            }
        }

        onError: error => {
            // Hyprland CIERRA la conexión tras cada respuesta, y
            // Quickshell lo reporta como PeerClosedError (código 1).
            // Si ya hay datos en el buffer, es el fin normal de la
            // petición (igual que el `read() == 0` de `hyprctl`):
            // NO hacer nada aquí, la desconexión que sigue la
            // completará vía finishOk. No mutar el socket en este
            // handler (reentrancia → crash).
            root.lastError = String(error);
            if (root.currentCommand !== "" && root.buffer !== "")
                return;
            // Sin datos: fallo real (p.ej. socket ausente en el
            // connect) o cierre anómalo. Si hubo conexión previa, el
            // onConnectedChanged(false) que sigue lo completará; si
            // nunca conectamos, el watchdog lo convierte en fallo.
            // Solo se registra; no se muta el socket aquí.
        }
    }
}
