pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Propiedades que consume UpdateCounter
    property alias updateCount: persistent.updateCount
    property bool checking: false
    property bool updating: false
    property bool failed: false
    // Evita repetir el chequeo inicial (timer + al recuperar la red).
    property bool startupCheckDone: false
    // Si `checkupdates` no existe (no-Arch), se detecta una vez (exit 127)
    // y se deja de spawnear en cada ciclo: sin esto cada poll lanzaba un
    // proceso condenado al fallo.
    property bool checkerMissing: false

    property ListModel packagesToUpdate: ListModel {}

    // Watchdog: checkupdates es rápido; si se cuelga no debe wedgar el
    // ciclo (checking eterno, icono girando). Se mata y se marca failed
    // como cualquier otro fallo.
    property Timer countWatchdog: Timer {
        interval: 120000
        onTriggered: {
            if (countUpdates.running) {
                console.warn("[Updates] timeout chequeando, mato checkupdates");
                countUpdates.running = false;
            }
        }
    }

    function tryStartupCheck() {
        if (root.startupCheckDone || root.checkerMissing)
            return;
        if (!NetworkService?.hasInternet)
            return;
        // Solo inicial y sin colisionar: si ya hay un chequeo o una
        // actualización en curso, se da por cumplido y no se duplica.
        if (countUpdates.running || root.checking || root.updating) {
            root.startupCheckDone = true;
            startupTimer.stop();
            return;
        }
        root.startupCheckDone = true;
        startupTimer.stop();
        countUpdates.running = true;
    }

    function checkNow() {
        if (root.checkerMissing)
            return;
        countUpdates.running = true;
    }

    function update() {
        // Sin comando no hay nada que lanzar: evita abrir un terminal
        // vacío si la config quedó en blanco.
        if (root.updateArgs().length === 0) {
            console.warn("[Updates] comando vacío, no se lanza actualización");
            return;
        }
        updateProcess.running = true;
    }

    // Parseo del comando configurable (Settings → updates.command)
    // respetando comillas simples/dobles y `\` de escape, en vez de un
    // split(" ") ciego que rompía args con espacios y cambiaba el
    // significado del comando.
    function updateArgs() {
        const out = [];
        let cur = "";
        let quote = "";
        let escaped = false;
        let has = false;
        const src = String(ConfigService.configs.updates.command ?? "");
        for (let i = 0; i < src.length; i++) {
            const c = src[i];
            if (escaped) {
                cur += c;
                escaped = false;
                has = true;
                continue;
            }
            if (c === "\\" && quote !== "'") {
                escaped = true;
                continue;
            }
            if (quote !== "") {
                if (c === quote)
                    quote = "";
                else
                    cur += c;
                has = true;
                continue;
            }
            if (c === "'" || c === '"') {
                quote = c;
                has = true;
                continue;
            }
            if (c === " " || c === "\t" || c === "\n") {
                if (has) {
                    out.push(cur);
                    cur = "";
                    has = false;
                }
                continue;
            }
            cur += c;
            has = true;
        }
        if (escaped)
            cur += "\\";
        if (has)
            out.push(cur);
        return out;
    }

    PersistentProperties {
        id: persistent

        reloadableId: "updatePersistence"

        property int updateCount: 0
    }

    Timer {
        id: pollTimer

        // Sujeto a la config: mínimo 1 min, y se reinicia si countTime cambia.
        interval: Math.max(1, ConfigService.configs.updates.countTime) * 60000
        running: true
        repeat: true
        // Sin internet no hay nada que comprobar: evita marcar failed
        // en cada ciclo cuando la red está caída. Tampoco pisa un
        // chequeo o actualización ya en curso.
        onTriggered: {
            if (root.checkerMissing)
                return;
            if (!(NetworkService?.hasInternet ?? true))
                return;
            if (countUpdates.running || root.checking || root.updating)
                return;
            countUpdates.running = true;
        }
    }

    // Chequeo único al arrancar si hay internet: un solo disparo
    // diferido (60s, fuera del pico de inicialización) para no pisar el
    // arranque, más un reintento al recuperar la red solo si el inicial
    // no llegó a ejecutarse.
    Timer {
        id: startupTimer

        interval: 60000
        running: true
        repeat: false
        onTriggered: root.tryStartupCheck()
    }

    Connections {
        target: ConfigService.configs.updates

        function onCountTimeChanged() {
            pollTimer.restart();
        }
    }

    Connections {
        target: NetworkService

        function onHasInternetChanged() {
            if (!root.startupCheckDone)
                root.tryStartupCheck();
        }
    }

    Process {
        id: countUpdates

        command: ["checkupdates"]

        onRunningChanged: {
            if (running) {
                root.checking = true;
                root.failed = false;
                root.packagesToUpdate.clear();
                root.countWatchdog.restart();
            } else {
                root.checking = false;
                root.countWatchdog.stop();
            }
        }

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "")
                    return;

                // formato: "nombre ver_antigua -> ver_nueva"
                const parts = line.split(" ");
                if (parts.length >= 4) {
                    root.packagesToUpdate.append({
                                                     name: parts[0],
                                                     oldVersion: parts[1],
                                                     newVersion: parts[3]
                                                 });
                }
            }
        }

        // qmllint disable signal-handler-parameters
        onExited: exitCode => {
            if (exitCode === 127) {
                // Binario ausente (p. ej. no-Arch): no reintentar en cada
                // ciclo. Se marca failed una vez para que el icono avise.
                root.checkerMissing = true;
                root.failed = true;
                return;
            }
            if (exitCode === 0 || exitCode === 2) {
                root.updateCount = root.packagesToUpdate.count;
                root.failed = false;
            } else {
                root.failed = true;
            }
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: updateProcess
        // El comando de la config se parsea con updateArgs() (respeta
        // comillas) y se expande como argv, sin pasar por shell.

        command: ["xdg-terminal-exec", "--app-id=local.floating", "-e", ...root.updateArgs()]

        onRunningChanged: {
            root.updating = running;
        }

        // qmllint disable signal-handler-parameters
        onExited: exitCode => {
            if (!countUpdates.running)
                countUpdates.running = true;
        }
        // qmllint enable signal-handler-parameters
    }

    IpcHandler {
        target: "update"

        function updateSystem() {
            root.update();
        }
    }
}
