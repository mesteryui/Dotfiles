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

    property ListModel packagesToUpdate: ListModel {}

    function tryStartupCheck() {
        if (root.startupCheckDone)
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
        countUpdates.running = true;
    }

    function update() {
        updateProcess.running = true;
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
            } else {
                root.checking = false;
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

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 || exitCode === 2) {
                root.updateCount = root.packagesToUpdate.count;
                root.failed = false;
            } else {
                root.failed = true;
            }
        }
    }

    Process {
        id: updateProcess
        // Separa el comando de la config por espacios y expande los argumentos dentro del array base

        command: ["xdg-terminal-exec", "--app-id=local.floating", "-e", ...ConfigService.configs.updates.command.split(" ").filter(s => s !== "")]

        onRunningChanged: {
            root.updating = running;
        }

        onExited: (exitCode, exitStatus) => {
            if (!countUpdates.running)
                countUpdates.running = true;
        }
    }

    IpcHandler {
        target: "update"

        function updateSystem() {
            root.update();
        }
    }
}
