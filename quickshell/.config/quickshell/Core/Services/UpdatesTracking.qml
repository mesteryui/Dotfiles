pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Propiedades que consume UpdateCounter
    property alias updateCount: persistent.updateCount
    property bool  checking:    false
    property bool  updating:    false
    property bool  failed:      false

    property ListModel packagesToUpdate: ListModel {}

    PersistentProperties {
        id: persistent
        reloadableId: "updatePersistence"
        property int updateCount: 0
    }

    Timer {
        interval: ConfigService.configs.updates.countTime * 60000
        running:  true
        repeat:   true
        onTriggered: countUpdates.running = true
    }

    Process {
        id: countUpdates
        command: ["checkupdates"]

        onRunningChanged: {
            if (running) {
                root.checking = true
                root.failed   = false
                root.packagesToUpdate.clear()
            } else {
                root.checking = false
            }
        }

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line === "") return

                // formato: "nombre ver_antigua -> ver_nueva"
                const parts = line.split(" ")
                if (parts.length >= 4) {
                    root.packagesToUpdate.append({
                        name:       parts[0],
                        oldVersion: parts[1],
                        newVersion: parts[3]
                    })
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 || exitCode === 2) {
                root.updateCount = root.packagesToUpdate.count
                root.failed      = false
                
                // Persistir lista de paquetes
                let list = []
                for (let i = 0; i < root.packagesToUpdate.count; i++) {
                    list.push(root.packagesToUpdate.get(i))
                }
                persistent.packageList = list
            } else {
                root.failed = true
            }
        }
    }

    Process {
        id: updateProcess
        // Separa el comando de la config por espacios y expande los argumentos dentro del array base
        command: ["xdg-terminal-exec", "--app-id=local.floating", "-e", ...ConfigService.configs.updates.command.split(" ")]

        onRunningChanged: {
            root.updating = running
        }

        onExited: (exitCode, exitStatus) => {
            countUpdates.running = true
        }
    }
    function checkNow() {
        countUpdates.running = true
    }
    function update() {
        updateProcess.running = true
    }
}
