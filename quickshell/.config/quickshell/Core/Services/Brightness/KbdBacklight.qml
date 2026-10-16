pragma Singleton
pragma ComponentBehavior: Bound

import "DdcUtils.js" as DdcUtils
import QtQuick
import Quickshell
import Quickshell.Io

// Retroiluminación del teclado (p. ej. asus::kbd_backlight, 4 niveles).
// Niveles discretos: las teclas mueven ±1 nivel; el slider mapea 0..1.
// Sin device (sobremesa) → supported=false y el OSD no se registra.
Singleton {
    id: root

    property string device: ""
    property int rawValue: 0
    property int maxValue: 1
    readonly property real brightness: root.maxValue > 0 ? root.rawValue / root.maxValue : 0
    // Orden de asignación: brightness primero y ready al final, para que el
    // OSD (guardado por ready) no flashee al arrancar.
    property bool ready: false
    property bool supported: false

    property bool _brightLoaded: false
    property bool _maxLoaded: false

    function load() {
    }

    Component.onCompleted: detectProc.running = true

    function setBrightness(value: real): int {
        if (!root.supported || !root.ready || root.device === "")
            return -1;
        const raw = Math.max(0, Math.min(root.maxValue, Math.round(value * root.maxValue)));
        if (raw === root.rawValue)
            return -1;
        // Asignación optimista: sysfs no emite inotify fiable y el eco por
        // watchChanges puede no llegar nunca. Se confirma con reload (300ms)
        // y un drift lento caza cambios de teclas de firmware.
        root.rawValue = raw;
        Quickshell.execDetached(["brightnessctl", "-d", root.device, "s", String(raw), "--quiet"]);
        writeTimer.restart();
        return raw;
    }

    function increase() {
        if (root.maxValue > 0)
            root.setBrightness((root.rawValue + 1) / root.maxValue);
    }

    function decrease() {
        if (root.maxValue > 0)
            root.setBrightness((root.rawValue - 1) / root.maxValue);
    }

    // Confirmación tras escritura propia (sysfs no avisa solo).
    Timer {
        id: writeTimer

        interval: 300
        onTriggered: {
            if (root.supported && brightnessView.path !== "")
                brightnessView.reload();
        }
    }

    // Caza cambios externos (teclas Fn de firmware): una lectura cada 5s
    // es despreciable y sin cambios no emite ninguna señal. Así el OSD sale
    // aunque el firmware se coma las teclas y los binds no lleguen a correr.
    // (Antes 1s: impedía deep-sleep por un reload sysfs constante.)
    Timer {
        id: driftTimer

        interval: 5000
        repeat: true
        running: root.supported
        onTriggered: {
            if (brightnessView.path !== "")
                brightnessView.reload();
        }
    }

    Process {
        id: detectProc

        command: ["sh", "-c", 'ls /sys/class/leds/ 2>/dev/null | grep -m1 -E "kbd_backlight|^kbd" || true']
        stdout: StdioCollector {
            onStreamFinished: {
                const dev = text.trim();
                if (dev !== "") {
                    root.device = dev;
                    root.supported = true;
                    brightnessView.path = `/sys/class/leds/${dev}/brightness`;
                    maxView.path = `/sys/class/leds/${dev}/max_brightness`;
                    brightnessView.reload();
                    maxView.reload();
                }
            }
        }
    }

    FileView {
        id: brightnessView

        path: ""
        watchChanges: true
        onLoaded: {
            root.rawValue = parseInt(this.text().trim()) || 0;
            root._brightLoaded = true;
            root._syncState();
        }
    }

    FileView {
        id: maxView

        path: ""
        onLoaded: {
            root.maxValue = parseInt(this.text().trim()) || 1;
            root._maxLoaded = true;
            root._syncState();
        }
    }

    function _syncState() {
        if (!root._brightLoaded || !root._maxLoaded)
            return;
        // brightness se recalcula solo (binding de rawValue/maxValue);
        // ready va el último para no disparar el OSD al arrancar.
        root.ready = true;
    }

    IpcHandler {
        target: "kbd_brightness"

        function increment() {
            root.increase();
        }

        function decrement() {
            root.decrease();
        }

        function get(): real {
            return root.brightness;
        }

        function set(value: string): string {
            const r = DdcUtils.parseSetValue(value, root.brightness);
            if (!r.ok)
                return "Invalid value: " + r.error;
            const raw = root.setBrightness(r.value);
            if (raw < 0)
                return "Already at level " + root.rawValue + "/" + root.maxValue;
            return "Set keyboard to level " + raw + "/" + root.maxValue;
        }
    }
}
