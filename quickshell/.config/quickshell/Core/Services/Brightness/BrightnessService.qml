pragma Singleton
pragma ComponentBehavior: Bound

import qs.Core.Services as CoreServices
import "DdcUtils.js" as DdcUtils
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Fachada multi-monitor: un BrightnessMonitor por pantalla (ver
// BrightnessMonitor.qml) + API maestra compatible con el servicio antiguo
// (brightness/ready/setBrightness/adjustBrightness + IPC increment/decrement).
// - Interno (eDP): sysfs vía FileView, instantáneo y reactivo.
// - Externo HDMI: DDC/CI vía ddcutil (lento, con debounce). Sin ddcutil el
//   HDMI queda como no soportado y el interno funciona igual que antes.
// - syncAll=false (persistido, por defecto): teclas y slider van al monitor
//   enfocado (como end-4/caelestia). Con syncAll=true mueven todas al mismo %.
Singleton {
    id: root

    // Nota: sin `signal brightnessChanged` explícita — colisiona con la
    // señal auto-generada de la propiedad `brightness` de abajo. Los
    // consumidores (OSD/slider) ya escuchan el cambio de propiedad.

    // --- Detección (una pasada por arranque / hotplug) ---
    property list<var> ddcMonitors: []
    property list<var> backlightDevices: []
    property bool detectReady: false
    property bool _ddcWarned: false

    readonly property var ddcMonitorMap: {
        const map = {};
        for (let i = 0; i < root.ddcMonitors.length; i++)
            map[root.ddcMonitors[i].connector] = root.ddcMonitors[i];
        return map;
    }

    function backlightFor(screenName: string): string {
        for (let i = 0; i < root.backlightDevices.length; i++) {
            if (root.backlightDevices[i].drm === screenName)
                return root.backlightDevices[i].device;
        }
        // Fallback solo con 1 pantalla y 1 backlight (portátil sin HDMI):
        // con más pantallas asignar a ciegas movería el brillo ajeno.
        if (Quickshell.screens.length === 1 && root.backlightDevices.length === 1)
            return root.backlightDevices[0].device;
        return "";
    }

    // --- Monitores (uno por pantalla, ciclo de vida imperativo) ---
    // NOTA: Variants + QtObject produce delegados zombi en esta versión
    // (propiedades/métodos inaccesibles); end-4 usa createObject explícito.
    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    property list<var> monitors: []

    // Sincroniza objetos con Quickshell.screens (alta/baja real, sin fugas).
    // list<var> no notifica mutaciones: se emite monitorsChanged a mano,
    // solo si hubo cambios (si no, onMonitorsChanged relanzaría detección).
    function syncMonitors() {
        const screens = Quickshell.screens;
        let changed = false;
        for (let i = root.monitors.length - 1; i >= 0; i--) {
            if (screens.indexOf(root.monitors[i].modelData) < 0) {
                root.monitors[i].destroy();
                root.monitors.splice(i, 1);
                changed = true;
            }
        }
        for (let s = 0; s < screens.length; s++) {
            let found = false;
            for (let k = 0; k < root.monitors.length; k++) {
                if (root.monitors[k].modelData === screens[s]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                const m = monitorComp.createObject(root, {
                                                       modelData: screens[s]
                                                   });
                if (m) {
                    root.monitors.push(m);
                    changed = true;
                } else {
                    console.warn("[Brightness] no se pudo crear monitor para " + screens[s].name);
                }
            }
        }
        if (changed)
            root.monitorsChanged();
    }

    readonly property var focusedMonitor: {
        const name = Hyprland.focusedMonitor?.name ?? "";
        return root.monitors.find(m => m.screenName === name) ?? root.monitors[0] ?? null;
    }

    // --- API maestra (compatible con el servicio mono-monitor) ---
    readonly property real brightness: (root.focusedMonitor?.brightness ?? root.monitors[0]?.brightness) ?? 0

    readonly property bool ready: root.monitors.some(m => m.ready)

    // Enfocado por defecto (estilo end-4/caelestia): mismo % en todas
    // solo con syncAll=true (IPC `toggleSync` o config persistida).
    property bool syncAll: false

    function setSyncAll(v: bool) {
        root.syncAll = !!v;
        if (CoreServices.ConfigService.ready)
            CoreServices.ConfigService.configs.brightness.syncAll = root.syncAll;
    }

    Connections {
        target: CoreServices.ConfigService

        function onReadyChanged() {
            if (CoreServices.ConfigService.ready)
                root.syncAll = CoreServices.ConfigService.configs.brightness.syncAll ?? false;
        }
    }

    function targets(): var {
        const live = root.monitors.filter(m => m.supported && m.ready);
        if (root.syncAll)
            return live;
        const f = root.focusedMonitor;
        return (f && f.supported && f.ready) ? [f] : [];
    }

    function setBrightness(value: real) {
        const v = Math.max(0, Math.min(1, value));
        const ts = root.targets();
        for (let i = 0; i < ts.length; i++)
            ts[i].setBrightness(v);
    }

    function adjustBrightness(delta: real) {
        root.setBrightness(root.brightness + delta);
    }

    function refresh() {
        for (let i = 0; i < root.monitors.length; i++)
            root.monitors[i].refresh();
    }

    // --- Secuencia de detección + init ---
    Component.onCompleted: {
        if (CoreServices.ConfigService.ready)
            root.syncAll = CoreServices.ConfigService.configs.brightness.syncAll ?? false;
        root.syncMonitors();
        backlightProc.running = true;
    }

    // Hotplug a prueba de balas: handler de propiedad propia (siempre
    // dispara) en vez de depender del nombre de la señal de Quickshell.
    readonly property int screenCount: Quickshell.screens.length

    onScreenCountChanged: {
        root.syncMonitors();
        if (root.detectReady && !root._detecting)
            root.redetect();
    }

    onMonitorsChanged: {
        if (root.detectReady && !root._detecting)
            root.redetect();
    }

    property bool _detecting: false

    function redetect() {
        root.detectReady = false;
        root._detecting = true;
        backlightProc.running = true;
    }

    function initAllMonitors() {
        const claimed = [];
        for (let i = 0; i < root.monitors.length; i++) {
            const m = root.monitors[i];
            const info = root.ddcMonitorMap[m.screenName] ?? null;
            // Dos conectores en el mismo bus (MST): reclama el primero.
            if (info && claimed.indexOf(info.busNum) >= 0)
                m.ddcInfo = null;
            else {
                m.ddcInfo = info;
                if (info)
                    claimed.push(info.busNum);
            }
            m.backlightDevice = root.backlightFor(m.screenName);
            m.initBrightness();
        }
    }

    Process {
        id: backlightProc

        command: ["sh", "-c",
            'for d in /sys/class/backlight/*; do [ -d "$d" ] || continue; echo "$(basename "$d")|$(readlink "$d")"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                root.backlightDevices = DdcUtils.parseBacklightList(text);
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: ddcProc.running = true
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: ddcProc

        // Envuelto en sh: si ddcutil no existe, un Process directo falla al
        // arrancar y onExited podría no dispararse (cadena estancada). Así
        // siempre hay exit 0 con stdout vacío → DDC deshabilitado sin drama.
        command: ["sh", "-c", "command -v ddcutil >/dev/null && ddcutil detect --brief || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ddcMonitors = DdcUtils.parseDetect(text);
            }
        }
        // qmllint disable signal-handler-parameters
        onExited: code => {
            // 127 = ddcutil no instalado: HDMI sin soporte, interno intacto.
            if (code === 127 && !root._ddcWarned) {
                root._ddcWarned = true;
                console.info(
                            "[Brightness] ddcutil ausente: monitores DDC deshabilitados (instala ddcutil + grupo i2c para HDMI)");
            }
            root.detectReady = true;
            root._detecting = false;
            root.initAllMonitors();
        }
        // qmllint enable signal-handler-parameters
    }

    // --- IPC ---
    // getMonitor: "active" | "all" | "<nombre>" (eDP-1, HDMI-A-1...).
    function getMonitor(query: string): var {
        if (query === "active")
            return root.focusedMonitor;
        if (query === "all")
            return null;
        return root.monitors.find(m => m.screenName === query) ?? null;
    }

    IpcHandler {
        target: "brightness"

        // Compat: `qs ipc call brightness increment 5` (teclas Hyprland).
        function increment(value: int) {
            root.adjustBrightness((value || 5) / 100);
        }

        function decrement(value: int) {
            root.adjustBrightness(-((value || 5) / 100));
        }

        function get(): real {
            return root.brightness;
        }

        function set(value: string): string {
            return setFor("active", value);
        }

        function getFor(query: string): real {
            if (query === "all")
                return root.brightness;
            return root.getMonitor(query)?.brightness ?? -1;
        }

        function setFor(query: string, value: string): string {
            if (query === "all") {
                const r = DdcUtils.parseSetValue(value, root.brightness);
                if (!r.ok)
                    return "Invalid value: " + r.error;
                root.setBrightness(r.value);
                return "Set all monitors to " + Math.round(root.brightness * 100) + "%";
            }
            const monitor = root.getMonitor(query);
            if (!monitor)
                return "Invalid monitor: " + query + " (try active/all/" + root.monitors.map(m
                                                                                             => m.screenName).join(
                            ", ") + ")";
            const r = DdcUtils.parseSetValue(value, monitor.brightness);
            if (!r.ok)
                return "Invalid value: " + r.error;
            monitor.setBrightness(r.value);
            return "Set " + monitor.screenName + " to " + Math.round(monitor.brightness * 100) + "%";
        }

        function debug(): string {
            const arr = [];
            for (let i = 0; i < root.monitors.length; i++) {
                const m = root.monitors[i];
                arr.push({
                             screen: m.screenName,
                             typeofInit: typeof m.initBrightness,
                             brightness: m.brightness,
                             ready: m.ready,
                             supported: m.supported,
                             backend: m.isDdc ? ("ddc:" + m.busNum) : ("bl:" + m.backlightDevice)
                         });
            }
            return JSON.stringify({
                                      count: root.monitors.length,
                                      detectReady: root.detectReady,
                                      ddc: root.ddcMonitors,
                                      bl: root.backlightDevices,
                                      mons: arr
                                  });
        }

        function toggleSync(): string {
            root.setSyncAll(!root.syncAll);
            return "syncAll=" + root.syncAll;
        }

        function refresh(): void {
            root.refresh();
        }
    }
}
