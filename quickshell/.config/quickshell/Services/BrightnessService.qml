pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string device: ""
    property int rawValue: 0
    property int maxValue: 1
    readonly property real brightness: maxValue > 0 ? rawValue / maxValue : 0

    // ← añadir esto
    property bool ready: false

    Process {
        id: detectProc
        command: ["sh", "-c", "ls /sys/class/backlight/ | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const dev = this.text.trim()
                if (dev !== "") {
                    root.device = dev
                    brightnessView.path = `/sys/class/backlight/${dev}/brightness`
                    maxView.path = `/sys/class/backlight/${dev}/max_brightness`
                    brightnessView.reload()
                    maxView.reload()
                }
            }
        }
    }

    FileView {
        id: brightnessView
        path: ""
        watchChanges: true
        onLoaded: {
            root.rawValue = parseInt(this.text().trim()) || 0
            if (root.maxValue > 1) root.ready = true  // ← ambos cargados
        }
    }

    FileView {
        id: maxView
        path: ""
        onLoaded: {
            root.maxValue = parseInt(this.text().trim()) || 1
            if (root.rawValue > 0) root.ready = true  // ← ambos cargados
        }
    }

    Process {
        id: setProc
        stdout: StdioCollector {
            onStreamFinished: brightnessView.reload()
        }
    }

    function setBrightness(value: real): void {
        if (root.device === "") return
        const clamped = Math.max(0.05, Math.min(1.0, value))
        const percent = Math.round(clamped * 100)
        setProc.command = ["brightnessctl", "-d", root.device, "set", percent + "%"]
        setProc.running = true
    }

    function adjustBrightness(delta: real): void {
        setBrightness(root.brightness + delta)
    }

    IpcHandler {
        target: "brightness"
        function increment(value: int) { root.adjustBrightness((value / 100)) }
        function decrement(value: int) { root.adjustBrightness(-(value/100)) }
    }
}