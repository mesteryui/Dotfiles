pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Estado de actualizaciones del backend shinro.
//
// Este servicio no conoce la distribución ni ejecuta gestores de paquetes:
// pide al daemon que compruebe (pacman/dnf/apt/xbps, AUR, Flatpak o un
// comando genérico) y pinta el resultado. El backend comparte una sola
// comprobación entre todos los clientes y guarda el estado solo en RAM, así
// que tras reiniciar el contador muestra "—" hasta la primera comprobación.
Singleton {
    id: root

    // ── Estado que consume la UI ────────────────────────────────
    property int updateCount: 0
    property bool checking: false
    // `updating` refleja la actualización reportada por el backend.
    readonly property bool updating: root._backendUpdating
    property bool failed: false
    // checked_at == 0 significa "nunca comprobado en esta sesión".
    property bool checked: false
    property int checkedAt: 0
    property bool canUpdate: false
    property string updateScript: ""
    property string updatingBackend: ""
    property var backends: []
    property var errors: []

    property ListModel packagesToUpdate: ListModel {}

    // El contador de la barra muestra "—" mientras no haya un resultado.
    readonly property string displayCount: root.checked ? String(root.updateCount) : "—"

    // El backend decide el comando; la UI solo lo ejecuta en un terminal.
    readonly property bool canUpdateNow: root.updateScript.length > 0

    property bool _backendUpdating: false

    // ── Socket Unix del backend shinro ──────────────────────────
    // Conexión persistente: el backend empuja el estado tras el hello y
    // nunca cierra. Quickshell no reconecta solo, así que reconnectTimer
    // reintenta y onConnectionStateChanged reenvía el hello.
    readonly property string socketPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR");
        if (rt)
            return rt + "/shinro";
        const uid = Quickshell.env("UID");
        return uid ? "/run/user/" + uid + "/shinro" : "";
    }

    // countTime está en minutos (config); el protocolo usa segundos con un
    // mínimo de 300 s. 0 o negativo desactiva la comprobación periódica.
    readonly property int checkIntervalSeconds: {
        const minutes = Number(ConfigService.configs.updates.countTime ?? 0);
        if (!(minutes > 0))
            return 0;
        return Math.max(300, Math.round(minutes * 60));
    }

    // `updates.backends` acepta "all" o una lista separada por comas
    // ("pacman,aur,flatpak"). "all" activa todos los backends detectados.
    function backendList(): var {
        const raw = String(ConfigService.configs.updates.backends ?? "all").trim();
        if (raw === "" || raw === "all")
            return ["all"];
        return raw.split(",").map(v => v.trim()).filter(v => v !== "");
    }

    // Suscribe este cliente al módulo updates. Es idempotente: reenviarlo
    // reconfigura backends e intervalo sin reiniciar la conexión.
    function _sendHello(): void {
        if (!shinroSocket.connected)
            return;
        shinroSocket.write(JSON.stringify({
                                              type: "hello",
                                              intervals: {
                                                  updates: root.checkIntervalSeconds
                                              },
                                              updates: {
                                                  backends: root.backendList()
                                              }
                                          }) + "\n");
        shinroSocket.flush();
    }

    // Pide una acción al módulo: "check" comprueba y "update" actualiza.
    // El resultado llega por el mismo socket (respuesta + broadcast).
    function _request(action: string): void {
        if (!shinroSocket.connected)
            return;
        shinroSocket.write(JSON.stringify({
                                              type: "get",
                                              module: "updates",
                                              action: action
                                          }) + "\n");
        shinroSocket.flush();
    }

    function checkNow(): void {
        if (root.checking || root.updating)
            return;
        root._request("check");
    }

    function isSafeUpdateScript(script): bool {
        const s = String(script || "").trim();
        if (s.length === 0 || s.length > 4096)
            return false;
        if (/[\u0000-\u001F\u007F]/.test(s))
            return false;
        // Bloquea sustitución, redirecciones, tuberías, separadores, subshells.
        if (/[`$;|<>(){}!]/.test(s))
            return false;
        // Solo permite && como operador.
        const withoutAnd = s.replace(/&&/g, "");
        if (withoutAnd.indexOf("&") >= 0)
            return false;
        const parts = s.split("&&").map(p => p.trim()).filter(p => p.length > 0);
        if (parts.length === 0)
            return false;
        // Allowlist conservadora de caracteres para comandos argv-like.
        const ok = /^[A-Za-z0-9_./:@%+=,'"\- ]+$/;
        for (let i = 0; i < parts.length; i++) {
            if (!ok.test(parts[i]))
                return false;
        }
        return true;
    }

    function update(): void {
        if (root.checking || root.updating || updateProcess.running)
            return;

        // Por seguridad, la actualización SIEMPRE se ejecuta en un terminal
        // interactivo. El backend decide el script según los backends
        // detectados; la UI no elige ni sobreescribe ese comando.
        const script = String(root.updateScript || "").trim();
        if (script.length === 0) {
            console.warn("[Updates] el backend no expuso update_script");
            return;
        }
        if (!root.isSafeUpdateScript(script)) {
            console.warn("[Updates] update_script rechazado por validación de seguridad");
            return;
        }
        updateProcess.command = ["xdg-terminal-exec", "--app-id=local.floating", "--", "sh", "-c", script];
        updateProcess.running = true;
    }

    // Vuelca el mensaje `update` del módulo en las propiedades y el modelo.
    function _applyState(d: var): void {
        if (!d)
            return;

        root.checking = d.checking === true;
        root._backendUpdating = d.updating === true;
        root.updatingBackend = d.updating_backend ?? "";
        root.canUpdate = d.can_update === true;
        root.updateScript = d.update_script ?? "";
        root.checkedAt = d.checked_at ?? 0;
        root.checked = root.checkedAt > 0;
        root.updateCount = d.count ?? 0;
        root.backends = d.backends ?? [];
        root.errors = d.errors ?? [];
        root.failed = root.errors.length > 0;

        // Durante una comprobación se conserva la lista anterior (evita
        // parpadeos); al terminar se reconstruye con el resultado fresco.
        if (root.checking)
            return;

        const packages = d.packages ?? [];
        root.packagesToUpdate.clear();
        for (const p of packages) {
            root.packagesToUpdate.append({
                                             name: p.name ?? "",
                                             oldVersion: p.old ?? "",
                                             newVersion: p.new ?? "",
                                             backend: p.backend ?? ""
                                         });
        }
    }

    Component.onCompleted: shinroSocket.connected = true

    Socket {
        id: shinroSocket

        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const msg = JSON.parse(data);
                    if (msg.type === "error") {
                        console.warn("[Updates] " + msg.message);
                        return;
                    }
                    if (msg.type !== "update" || msg.module !== "updates")
                        return;
                    root._applyState(msg.data);
                } catch (e) {
                    console.warn("[Updates] mensaje inválido:", e);
                }
            }
        }

        onConnectionStateChanged: {
            if (!shinroSocket.connected)
                return;
            // (Re)suscribirse: tras una reconexión el backend no conoce a
            // este cliente y el hello trae además el snapshot inicial.
            root._sendHello();
        }

        onError: error => {
            // No tocar `connected` aquí: reentrar en onSocketError de
            // Quickshell provoca un segfault. reconnectTimer se encarga.
        }
    }

    // Reconexión: solo corre mientras no haya conexión.
    Timer {
        id: reconnectTimer

        interval: 2000
        repeat: true
        running: root.socketPath !== "" && !shinroSocket.connected
        onTriggered: shinroSocket.connected = true
    }

    // Ejecuta el script decidido por el backend en un terminal y luego
    // pide una comprobación para refrescar el contador.
    Process {
        id: updateProcess

        // qmllint disable signal-handler-parameters
        onExited: exitCode => {
            root._request("check");
        }
        // qmllint enable signal-handler-parameters
    }

    // El intervalo y la lista de backends viajan en el hello: al cambiar la
    // config se renegocia en caliente, sin reconectar.
    Connections {
        target: ConfigService.configs.updates

        function onCountTimeChanged(): void {
            root._sendHello();
        }

        function onBackendsChanged(): void {
            root._sendHello();
        }
    }

    IpcHandler {
        target: "update"

        function updateSystem(): void {
            root.update();
        }

        function checkSystem(): void {
            root.checkNow();
        }
    }
}
