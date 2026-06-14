pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
Singleton {
    id: root
    property int updateNumbers: 0
    Process {
        id: countUpdates
        command: ["checkupdates", "-c", "|", "wc -l"]
        stdout: SplitParser {
            onRead: data => {
                root.updateNumbers = parseInt(data.trim())
            }
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