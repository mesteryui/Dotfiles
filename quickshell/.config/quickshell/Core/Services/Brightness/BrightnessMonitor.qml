// --- BrightnessMonitor (QtObject) ---
// Un monitor físico: interno (sysfs/backlight, rápido y reactivo) o
// externo HDMI (DDC/CI, lento: lectura ~1s, escritura con debounce).
// Lo crea BrightnessService (uno por pantalla vía Variants).
pragma ComponentBehavior: Bound

import "DdcUtils.js" as DdcUtils
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: monitor

    required property ShellScreen modelData
    // Info DDC resuelta por el servicio (null = no es DDC). Asignación
    // imperativa desde initAllMonitors (con dedup de bus), no binding.
    property var ddcInfo: null
    // Device backlight resuelto por el servicio ("" = sin backlight).
    property string backlightDevice: ""

    readonly property string screenName: modelData ? modelData.name : ""
    readonly property bool isDdc: ddcInfo !== null
    readonly property string busNum: ddcInfo?.busNum ?? ""
    // Etiqueta para sliders ("eDP-1", "HDMI-A-1 · DDC"...).
    readonly property string label: monitor.isDdc ? monitor.screenName + " · DDC" : monitor.screenName

    property int rawMax: 100
    property real brightness: 0
    property bool ready: false
    // false = sin backend válido (p. ej. HDMI sin ddcutil o sin VCP 10).
    property bool supported: false

    // Solo DDC: coalesca ráfagas (arrastrar slider/tecla repetida) en una
    // escritura. El backlight escribe directo (sysfs es instantáneo).
    property real queuedBrightness: NaN

    readonly property Timer ddcTimer: Timer {
        interval: 400
        onTriggered: {
            if (!isNaN(monitor.queuedBrightness)) {
                const v = monitor.queuedBrightness;
                monitor.queuedBrightness = NaN;
                monitor.writeDdc(v);
            }
        }
    }

    function initBrightness() {
        monitor.ready = false;
        monitor.supported = false;
        if (monitor.isDdc) {
            initProc.command = ["ddcutil", "-b", monitor.busNum, "getvcp", "10", "--brief"];
            initProc.running = true;
        } else if (monitor.backlightDevice !== "") {
            // Sin proceso: FileView lee sysfs al instante. OJO: sysfs no
            // emite inotify fiable, el watchChanges no basta para cambios
            // externos; las escrituras propias asignan optimista + el eco
            // confirma (ver setBrightness/writeBacklight).
            brightnessView.path = `/sys/class/backlight/${monitor.backlightDevice}/brightness`;
            maxView.path = `/sys/class/backlight/${monitor.backlightDevice}/max_brightness`;
            brightnessView.reload();
            maxView.reload();
        }
        // Sin backend: supported=false, el slider lo oculta con hint.
    }

    // El servicio asigna backends y llama a initBrightness() explícito
    // (initAllMonitors); sin auto-init aquí para no duplicar el getvcp DDC.

    function setBrightness(value: real) {
        const v = Math.max(0, Math.min(1, value));
        if (!monitor.supported || !monitor.ready)
            return;
        // Dedup por punto: evita tormentas DDC al repetir tecla en el tope.
        if (Math.round(v * 100) === Math.round(monitor.brightness * 100))
            return;
        monitor.brightness = v;
        if (monitor.isDdc) {
            if (monitor.ddcTimer.running) {
                monitor.queuedBrightness = v;
                return;
            }
            monitor.writeDdc(v);
            monitor.ddcTimer.restart();
        } else {
            monitor.writeBacklight(v);
        }
    }

    function writeDdc(value: real) {
        // Piso en 1: raw 0 apaga el panel en varios monitores.
        const raw = Math.max(Math.floor(value * monitor.rawMax), 1);
        Quickshell.execDetached(["ddcutil", "-b", monitor.busNum, "setvcp", "10", String(raw)]);
    }

    function writeBacklight(value: real) {
        const pct = Math.floor(value * 100);
        if (pct <= 0)
            Quickshell.execDetached(["brightnessctl", "-d", monitor.backlightDevice, "s", "1", "--quiet"]);
        else
            Quickshell.execDetached(["brightnessctl", "-d", monitor.backlightDevice, "s", pct + "%",
                                     "--quiet"]);
    }

    function refresh() {
        monitor.initBrightness();
    }

    readonly property Process initProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = DdcUtils.parseVcpBrief(text);
                if (parsed) {
                    monitor.rawMax = parsed.max;
                    monitor.brightness = parsed.current / parsed.max;
                    monitor.supported = true;
                    monitor.ready = true;
                } else {
                    console.warn("[Brightness] sin VCP 10 en " + monitor.screenName + " (bus "
                                 + monitor.busNum + ")");
                    monitor.supported = false;
                }
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: code => {
            // ddcutil ausente (127) o bus caído: degradado, no spam.
            if (code !== 0 && !monitor.ready) {
                console.warn("[Brightness] DDC no disponible en " + monitor.screenName + " (exit " + code
                             + ")");
                monitor.supported = false;
            }
        }
        // qmllint enable signal-handler-parameters
    }

    readonly property FileView brightnessView: FileView {
        path: ""
        watchChanges: true
        onLoaded: {
            monitor.rawValue = parseInt(this.text().trim()) || 0;
            monitor._brightLoaded = true;
            monitor._syncFromSysfs();
        }
    }

    readonly property FileView maxView: FileView {
        path: ""
        onLoaded: {
            monitor.rawMax = parseInt(this.text().trim()) || 100;
            monitor._maxLoaded = true;
            monitor._syncFromSysfs();
        }
    }

    property int rawValue: 0

    property bool _brightLoaded: false

    property bool _maxLoaded: false

    function _syncFromSysfs() {
        if (!monitor._brightLoaded || !monitor._maxLoaded)
            return;
        monitor.brightness = monitor.rawMax > 0 ? monitor.rawValue / monitor.rawMax : 0;
        monitor.supported = true;
        monitor.ready = true;
    }
}
