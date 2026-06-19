pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ── Intervalo de actualización (ms) ───────────────────────────
    readonly property int pollInterval: 2000

    // ── API pública: CPU ──────────────────────────────────────────
    readonly property real   cpuUsage:     _cpu.usage
    readonly property int    cpuCores:     _cpu.coreCount
    readonly property string cpuUsagePct:  Math.round(_cpu.usage * 100) + "%"
    readonly property int    cpuTemp:      _temp.value

    // ── API pública: Memoria ──────────────────────────────────────
    readonly property int    memTotalMiB:  _mem.totalMiB
    readonly property int    memUsedMiB:   _mem.usedMiB
    readonly property int    memFreeMiB:   _mem.availableMiB
    readonly property real   memUsage:     _mem.usage
    readonly property string memUsagePct:  Math.round(_mem.usage * 100) + "%"

    // ── API pública: Swap ─────────────────────────────────────────
    readonly property int    swapTotalMiB: _mem.swapTotalMiB
    readonly property int    swapUsedMiB:  _mem.swapUsedMiB
    readonly property real   swapUsage:    _mem.swapUsage

    // ── API pública: Uptime ───────────────────────────────────────
    readonly property string uptime:       _uptime.formatted
    readonly property real   uptimeSecs:   _uptime.seconds

    // ── API pública: Disco ────────────────────────────────────────
    readonly property string diskUsagePct: _disk.usagePct
    readonly property string diskUsed:     _disk.used
    readonly property string diskTotal:    _disk.total
    readonly property real   diskUsage:    _disk.usage

    // ═════════════════════════════════════════════════════════════
    // Internals: Motor Centralizado Asíncrono
    // ═════════════════════════════════════════════════════════════

    Process {
        id: sysProcess
        // Bucle infinito en bash que extrae toda la info en una sola pasada.
        // Mantiene 1 solo proceso vivo, reduciendo la carga del hilo principal.
        command: [
            "bash",
            "-c",
            `while true; do
                cat /proc/stat
                echo '---SEP---'
                cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0
                echo '---SEP---'
                cat /proc/meminfo
                echo '---SEP---'
                cat /proc/uptime
                echo '---SEP---'
                df -h /
                echo '===END==='
                sleep ${root.pollInterval / 1000}
            done`
        ]
        running: true

        stdout: SplitParser {
            // Este delimitador agrupa todo el ciclo en un solo callback
            splitMarker: "===END===\n"
            
            onRead: data => {
                const chunks = data.split("---SEP---\n")
                if (chunks.length >= 5) {
                    _cpu.parse(chunks[0])
                    _temp.parse(chunks[1])
                    _mem.parse(chunks[2])
                    _uptime.parse(chunks[3])
                    _disk.parse(chunks[4])
                }
            }
        }
    }

    // ── Adaptadores de Datos ──────────────────────────────────────

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
        property real _prevTotal: 0
        property real _prevIdle:  0

        function parse(raw) {
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

            coreCount = raw.split("\n").filter(l => /^cpu\d+/.test(l)).length
        }
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