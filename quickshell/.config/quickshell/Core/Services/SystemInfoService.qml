pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── Estado ──────────────────────────────────────────────────
    property bool hasData: false

    // ── Régimen de empuje ───────────────────────────────────────
    // Este servicio solo lo consume el dashboard (SysInfoTab); en reposo
    // nadie mira las métricas, así que el backend no debe calcularlas
    // cada 2 s. `setLive(true)` al abrir el panel pide 2 s y
    // `setLive(false)` al cerrarlo vuelve a 300 s (el snapshot inicial
    // de la suscripción ya pinta los valores al abrir).
    //
    // El backend arranca el pump con el primer hello y lo reinicia solo
    // al reconectar: cambiar el intervalo exige reenviar el hello (ver
    // system_module.go: interval <= 0 deja el pump muerto para siempre,
    // por eso jamás se manda 0).
    readonly property int idleInterval: 300

    readonly property int liveInterval: 2

    property int pushInterval: idleInterval

    function setLive(on: bool): void {
        const next = on ? root.liveInterval : root.idleInterval;
        if (root.pushInterval === next)
            return;
        root.pushInterval = next;
        root._sendHello();
    }

    function _sendHello(): void {
        if (!shinroSocket.connected)
            return;
        // Suscribirse al módulo system. El backend responde con un
        // snapshot inmediato y luego empuja cada pushInterval segundos.
        // No se envía `location`: este servicio no consume clima y no
        // debe sobrescribir la ubicación del WeatherService.
        shinroSocket.write(JSON.stringify({
                                              type: "hello",
                                              intervals: {
                                                  system: root.pushInterval,
                                                  weather: 0
                                              }
                                          }) + "\n");
        shinroSocket.flush();
    }

    // ── Socket Unix del backend shinro ──────────────────────────
    // Conexión persistente: el backend empuja datos y nunca cierra.
    // Quickshell no reconecta solo tras un error, así que lo hacemos con
    // reconnectTimer (mismo patrón que Hyprsunset.qml).
    readonly property string socketPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR");
        if (rt)
            return rt + "/shinro";
        const uid = Quickshell.env("UID");
        return uid ? "/run/user/" + uid + "/shinro" : "";
    }

    function fmtBytes(bytes) {
        const b = bytes ?? 0;
        if (b <= 0)
            return "0G";
        const gib = b / (1024 * 1024 * 1024);
        if (gib >= 1)
            return gib.toFixed(gib >= 10 ? 0 : 1) + "G";
        return (b / (1024 * 1024)).toFixed(0) + "M";
    }

    Socket {
        id: shinroSocket
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const msg = JSON.parse(data);
                    if (msg.type !== "update" || msg.module !== "system")
                        return;

                    const d = msg.data;

                    _cpu.usage = (d.cpu_percent ?? 0) / 100;
                    _cpu.coreCount = d.cpu_cores ?? 0;

                    _temp.value = d.temperature_c ?? -1;

                    _mem.usage = (d.ram_percent ?? 0) / 100;
                    _mem.totalMiB = Math.round((d.ram_total_gb ?? 0) * 1024);
                    _mem.usedMiB = Math.round((d.ram_used_gb ?? 0) * 1024);
                    _mem.availableMiB = Math.max(0, _mem.totalMiB - _mem.usedMiB);
                    _mem.swapTotalMiB = Math.round(d.swap_total_mib ?? 0);
                    _mem.swapUsedMiB = Math.round(d.swap_used_mib ?? 0);
                    _mem.swapUsage = (d.swap_percent ?? 0) / 100;

                    _uptime.seconds = d.uptime_seconds ?? 0;
                    const secs = _uptime.seconds;
                    const days = Math.floor(secs / 86400);
                    const hours = Math.floor((secs % 86400) / 3600);
                    const mins = Math.floor((secs % 3600) / 60);
                    if (days > 0)
                        _uptime.formatted = days + "d " + hours + "h " + mins + "m";
                    else if (hours > 0)
                        _uptime.formatted = hours + "h " + mins + "m";
                    else
                        _uptime.formatted = mins + "m";

                    _host.name = d.hostname || "";

                    _disk.total = root.fmtBytes(d.disk_total_bytes);
                    _disk.used = root.fmtBytes(d.disk_used_bytes);
                    _disk.usage = (d.disk_percent ?? 0) / 100;
                    _disk.usagePct = Math.round(d.disk_percent ?? 0) + "%";

                    root.hasData = true;
                } catch (e) {
                    console.warn("[SystemInfoService] mensaje inválido:", e);
                }
            }
        }

        onConnectionStateChanged: {
            if (!shinroSocket.connected)
                return;
            // (Re)suscribirse con el intervalo vigente: tras una
            // reconexión el backend no conoce este cliente.
            root._sendHello();
        }

        onError: error => {
            // No tocar `connected` aquí: Quickshell emite errorOccurred desde
            // QLocalSocket y modificar el estado reentra en onSocketError,
            // provocando un deleteLater() sobre un socket ya liberado
            // (segfault). reconnectTimer reintenta cuando `connected` pase a
            // false (o si nunca llegó a conectarse).
        }
    }

    // Reconexión: solo corre mientras no haya conexión.
    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: true
        running: root.socketPath !== "" && !shinroSocket.connected
        onTriggered: shinroSocket.connected = true
    }

    Component.onCompleted: shinroSocket.connected = true

    // ── API pública: CPU ──────────────────────────────────────────
    readonly property real cpuUsage: _cpu.usage

    readonly property int cpuCores: _cpu.coreCount

    readonly property string cpuUsagePct: Math.round(_cpu.usage * 100) + "%"

    readonly property int cpuTemp: _temp.value

    // ── API pública: Memoria ──────────────────────────────────────
    readonly property int memTotalMiB: _mem.totalMiB

    readonly property int memUsedMiB: _mem.usedMiB

    readonly property int memFreeMiB: _mem.availableMiB

    readonly property real memUsage: _mem.usage

    readonly property string memUsagePct: Math.round(_mem.usage * 100) + "%"

    // ── API pública: Swap ─────────────────────────────────────────
    readonly property int swapTotalMiB: _mem.swapTotalMiB

    readonly property int swapUsedMiB: _mem.swapUsedMiB

    readonly property real swapUsage: _mem.swapUsage

    // ── API pública: Uptime ───────────────────────────────────────
    readonly property string uptime: _uptime.formatted

    readonly property real uptimeSecs: _uptime.seconds

    // ── API pública: Host ─────────────────────────────────────────
    readonly property string hostname: _host.name

    // ── API pública: Disco ────────────────────────────────────────
    readonly property string diskUsagePct: _disk.usagePct

    readonly property string diskUsed: _disk.used

    readonly property string diskTotal: _disk.total

    readonly property real diskUsage: _disk.usage

    // ── Adaptadores de Datos (QtObjects para mantener la API) ─────

    QtObject {
        id: _cpu
        property real usage: 0.0
        property int coreCount: 0
    }

    QtObject {
        id: _temp
        property int value: 0
    }

    QtObject {
        id: _mem
        property int totalMiB: 0
        property int usedMiB: 0
        property int availableMiB: 0
        property real usage: 0.0
        property int swapTotalMiB: 0
        property int swapUsedMiB: 0
        property real swapUsage: 0.0
    }

    QtObject {
        id: _host
        property string name: ""
    }

    QtObject {
        id: _uptime
        property real seconds: 0
        property string formatted: ""
    }

    QtObject {
        id: _disk
        property string total: "0G"
        property string used: "0G"
        property string usagePct: "0%"
        property real usage: 0.0
    }
}
