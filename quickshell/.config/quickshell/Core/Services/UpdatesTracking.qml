pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int updateNumbers: 0
    property ListModel packagesToUpdate: ListModel {}

    Component.onCompleted: countUpdates.running = true

    Timer {
        interval: 3600000 // cada hora
        running: true
        repeat: true
        onTriggered: countUpdates.running = true
    }

    Process {
        id: countUpdates
        command: ["checkupdates"]

        onRunningChanged: {
            if (running) root.packagesToUpdate.clear()
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

        function onFinished(): void {
            root.updateNumbers = root.packagesToUpdate.count
        }
    }

    Process {
        id: updateProcess
        command: ["xdg-terminal-exec", "--app-id", "local.floating", "-e", "topgrade"]
    }

    function update() {
        updateProcess.running = true
    }

    Connections {
        target: updateProcess
        function onFinished(): void {
            countUpdates.running = true
        }
    }
}