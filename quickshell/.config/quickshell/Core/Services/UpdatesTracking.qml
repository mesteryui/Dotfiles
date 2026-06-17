pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Propiedades que consume UpdateCounter
    property int  updateCount: 0
    property bool checking:    false
    property bool updating:    false
    property bool failed:      false

    property ListModel packagesToUpdate: ListModel {}

    Component.onCompleted: countUpdates.running = true

    Timer {
        interval: 3600000 // cada hora
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

        // Señal correcta en Quickshell: exited(exitCode, exitStatus)
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 || exitCode === 2) {
                // checkupdates sale con 2 cuando no hay updates; ambos son éxito
                root.updateCount = root.packagesToUpdate.count
                root.failed      = false
            } else {
                root.failed = true
            }
        }
    }

    Process {
        id: updateProcess
        command: ["xdg-terminal-exec", "--app-id=local.floating", "-e", "sudo", "pacman", "-Syu"]

        onRunningChanged: {
            root.updating = running
        }

        onExited: (exitCode, exitStatus) => {
            countUpdates.running = true
        }
    }

    function update() {
        updateProcess.running = true
    }
}
