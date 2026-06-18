pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ── Intervalo de polling (ms) ─────────────────────────────────
    readonly property int pollInterval: 2000

    // ── API pública: CPU ──────────────────────────────────────────
    readonly property real   cpuUsage:     _cpu.usage      // 0.0 – 1.0
    readonly property int    cpuCores:     _cpu.coreCount
    readonly property string cpuUsagePct:  Math.round(_cpu.usage * 100) + "%"
    readonly property int    cpuTemp:      _temp.value     // Celsius

    // ── API pública: Memoria ──────────────────────────────────────
    readonly property int    memTotalMiB:  _mem.totalMiB
    readonly property int    memUsedMiB:   _mem.usedMiB
    readonly property int    memFreeMiB:   _mem.availableMiB
    readonly property real   memUsage:     _mem.usage      // 0.0 – 1.0
    readonly property string memUsagePct:  Math.round(_mem.usage * 100) + "%"

    // ── API pública: Swap ─────────────────────────────────────────
    readonly property int    swapTotalMiB: _mem.swapTotalMiB
    readonly property int    swapUsedMiB:  _mem.swapUsedMiB
    readonly property real   swapUsage:    _mem.swapUsage

    // ── API pública: Uptime ───────────────────────────────────────
    readonly property string uptime:       _uptime.formatted
    readonly property real   uptimeSecs:   _uptime.seconds

    // ── API pública: Disco ─────────────────────────────────────────
    readonly property string diskUsagePct: _disk.usagePct
    readonly property string diskUsed:     _disk.used
    readonly property string diskTotal:    _disk.total
    readonly property real   diskUsage:    _disk.usage

    // ═════════════════════════════════════════════════════════════
    // Internals
    // ═════════════════════════════════════════════════════════════

    // watchChanges: true NO funciona en /proc/ (sin inotify en sysfs/procfs).
    // Usamos un Timer que llama a reload() manualmente.
    Timer {
        interval: root.pollInterval
        running:  true
        repeat:   true
        triggeredOnStart: true
        onTriggered: {
            cpuFile.reload()
            memFile.reload()
            uptimeFile.reload()
            tempFile.reload()
            diskProcess.running = true // Trigger disk check
        }
    }

    // ── Proceso directo para obtener datos de disco ──────────────
    Process {
        id: diskProcess
        command: ["df", "-h", "/"]
        stdout: StdioCollector {
            onStreamFinished: _disk.parse(this.text)
        }
    }

    QtObject {
        id: _disk
        property string total:    "0G"
        property string used:     "0G"
        property string usagePct: "0%"
        property real   usage:    0.0

        function parse(raw) {
            const lines = raw.trim().split("\n")
            if (lines.length < 2) return
            const parts = lines[1].trim().split(/\s+/)
            if (parts.length >= 6) {
                total    = parts[1]
                used     = parts[2]
                usagePct = parts[4]
                usage    = parseInt(parts[4]) / 100
            }
        }
    }

    // ── /proc/stat → uso de CPU (delta entre muestras) ───────────
    FileView {
        id: cpuFile
        path: "/proc/stat"
        onTextChanged: _cpu.parse(text())
    }

    // ── /sys/class/thermal/thermal_zone0/temp → Temperatura ──────
    FileView {
        id: tempFile
        path: "/sys/class/thermal/thermal_zone0/temp"
        onTextChanged: _temp.parse(text())
    }

    QtObject {
        id: _temp
        property int value: 0
        function parse(raw) {
            const t = parseInt(raw.trim())
            if (!isNaN(t)) value = Math.round(t / 1000)
        }
    }

    QtObject {
        id: _cpu

        property real usage:     0.0
        property int  coreCount: 0

        // Estado previo para el cálculo delta
        property real _prevTotal: 0
        property real _prevIdle:  0

        function parse(raw) {
            // Línea 0: "cpu  user nice system idle iowait irq softirq steal ..."
            const parts = raw.split("\n")[0].trim().split(/\s+/)

            const user    = parseInt(parts[1])
            const nice    = parseInt(parts[2])
            const system  = parseInt(parts[3])
            const idle    = parseInt(parts[4])
            const iowait  = parseInt(parts[5])
            const irq     = parseInt(parts[6])
            const softirq = parseInt(parts[7])
            const steal   = parseInt(parts[8]) || 0

            const totalIdle   = idle + iowait
            const totalBusy   = user + nice + system + irq + softirq + steal
            const total       = totalIdle + totalBusy

            const dTotal = total - _prevTotal
            const dIdle  = totalIdle - _prevIdle

            if (dTotal > 0)
                usage = Math.max(0.0, Math.min(1.0, (dTotal - dIdle) / dTotal))

            _prevTotal = total
            _prevIdle  = totalIdle

            // Número de cores lógicos (líneas "cpu0", "cpu1", ...)
            coreCount = raw.split("\n").filter(l => /^cpu\d+/.test(l)).length
        }
    }

    // ── /proc/meminfo → RAM y Swap ────────────────────────────────
    FileView {
        id: memFile
        path: "/proc/meminfo"
        onTextChanged: _mem.parse(text())
    }

    QtObject {
        id: _mem

        property int  totalMiB:     0
        property int  usedMiB:      0
        property int  availableMiB: 0
        property real usage:        0.0
        property int  swapTotalMiB: 0
        property int  swapUsedMiB:  0
        property real swapUsage:    0.0

        function parse(raw) {
            // Helper: extrae el valor en KiB de una línea "Key: 12345 kB"
            function get(key) {
                const m = raw.match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))
                return m ? parseInt(m[1]) : 0
            }

            const totalKiB     = get("MemTotal")
            const availableKiB = get("MemAvailable")
            const swapTotalKiB = get("SwapTotal")
            const swapFreeKiB  = get("SwapFree")

            totalMiB     = Math.round(totalKiB / 1024)
            availableMiB = Math.round(availableKiB / 1024)
            usedMiB      = totalMiB - availableMiB
            usage        = totalMiB > 0 ? usedMiB / totalMiB : 0.0

            swapTotalMiB = Math.round(swapTotalKiB / 1024)
            swapUsedMiB  = Math.round((swapTotalKiB - swapFreeKiB) / 1024)
            swapUsage    = swapTotalMiB > 0 ? swapUsedMiB / swapTotalMiB : 0.0
        }
    }

    // ── /proc/uptime → tiempo encendido ──────────────────────────
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onTextChanged: _uptime.parse(text())
    }

    QtObject {
        id: _uptime

        property real   seconds:   0
        property string formatted: ""

        function parse(raw) {
            const secs = parseFloat(raw.split(" ")[0])
            seconds = secs

            const d = Math.floor(secs / 86400)
            const h = Math.floor((secs % 86400) / 3600)
            const m = Math.floor((secs % 3600) / 60)

            if      (d > 0) formatted = `${d}d ${h}h ${m}m`
            else if (h > 0) formatted = `${h}h ${m}m`
            else            formatted = `${m}m`
        }
    }
}
