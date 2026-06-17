import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../../Components"
import "../../../Core/Services" as Services
import "../../../Core"

Item {
    id: root

    // ── Tokens ────────────────────────────────────────────────────
    readonly property int   _radius:  16   // M3 medium shape
    readonly property int   _pad:     16
    readonly property int   _gap:     12

    // ── Helper: formatea MiB → "X.X GiB" o "XXX MiB" ────────────
    function fmtMem(mib) {
        return mib >= 1024
            ? (mib / 1024).toFixed(1) + " GiB"
            : mib + " MiB"
    }
    Layout.fillWidth:  true   // ← esto
    Layout.fillHeight: true

    // ─────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors {
            fill:    parent
            margins: root._pad
        }
        spacing: root._gap

        // ══ CPU Card ══════════════════════════════════════════════
        M3Card {
            Layout.fillWidth: true

            RowLayout {
                anchors { fill: parent; margins: root._pad }
                spacing: root._pad

                // Donut / arc de uso
                CpuArc {
                    id: cpuArc
                    size:  72
                    value: Services.SystemService.cpuUsage   // 0–1
                }

                // Textos
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // Label + badge de cores
                    RowLayout {
                        spacing: 8

                        Text {
                            text: "CPU"
                            font { pixelSize: 14; weight: Font.Medium }
                            color: Colors.md3.on_surface
                        }

                        // Chip de cores
                        Rectangle {
                            implicitWidth:  coreLabel.implicitWidth + 12
                            implicitHeight: 20
                            radius:         10
                            color:          Colors.md3.secondary_container

                            Text {
                                id: coreLabel
                                anchors.centerIn: parent
                                text:  Services.SystemService.cpuCores + " cores"
                                font { pixelSize: 11; weight: Font.Medium }
                                color: Colors.md3.on_secondary_container
                            }
                        }
                    }

                    // Porcentaje grande
                    Text {
                        text: Services.SystemService.cpuUsagePct ?? "0%"
                        font { pixelSize: 32; weight: Font.Bold }
                        color: Colors.md3.primary

                        Behavior on text { }   // solo para que no haga flash
                    }

                    // Barra de progreso
                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemService.cpuUsage ?? 0
                        accentColor: Colors.md3.primary
                    }
                }
            }
        }

        // ══ RAM + Swap Cards (fila) ════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: root._gap

            // ── RAM ─────────────────────────────────────────────
            M3Card {
                Layout.fillWidth: true

                ColumnLayout {
                    anchors { fill: parent; margins: root._pad }
                    spacing: 8

                    RowLayout {
                        Text {
                            text: "RAM"
                            font { pixelSize: 14; weight: Font.Medium }
                            color: Colors.md3.on_surface
                            Layout.fillWidth: true
                        }
                        Text {
                            text: Services.SystemService.memUsagePct ?? "0%"
                            font { pixelSize: 14; weight: Font.Bold }
                            color: Colors.md3.tertiary
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemService.memUsage ?? 0
                        accentColor: Colors.md3.tertiary
                    }

                    Text {
                        text: fmtMem(Services.SystemService.memUsedMiB ?? 0)
                             + " / "
                             + fmtMem(Services.SystemService.memTotalMiB ?? 0)
                        font.pixelSize: 11
                        color: Colors.md3.on_surface_variant
                    }
                }
            }

            // ── Swap ─────────────────────────────────────────────
            M3Card {
                Layout.fillWidth: true
                // Atenúa la card si no hay swap configurado
                opacity: (Services.SystemService.swapTotalMiB ?? 0) > 0 ? 1.0 : 0.45
                Behavior on opacity { NumberAnimation { duration: 300 } }

                ColumnLayout {
                    anchors { fill: parent; margins: root._pad }
                    spacing: 8

                    RowLayout {
                        Text {
                            text: "Swap"
                            font { pixelSize: 14; weight: Font.Medium }
                            color: Colors.md3.on_surface
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (Services.SystemService.swapTotalMiB ?? 0) > 0
                                ? Math.round((Services.SystemService.swapUsage ?? 0) * 100) + "%"
                                : "—"
                            font { pixelSize: 14; weight: Font.Bold }
                            color: Colors.md3.error
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemService.swapUsage ?? 0
                        accentColor: Colors.md3.error
                    }

                    Text {
                        text: (Services.SystemService.swapTotalMiB ?? 0) > 0
                            ? fmtMem(Services.SystemService.swapUsedMiB ?? 0)
                              + " / "
                              + fmtMem(Services.SystemService.swapTotalMiB ?? 0)
                            : "No swap"
                        font.pixelSize: 11
                        color: Colors.md3.on_surface_variant
                    }
                }
            }
        }

        // ══ Uptime Card ═══════════════════════════════════════════
        M3Card {
            Layout.fillWidth: true
            implicitHeight: 56

            RowLayout {
                anchors { fill: parent; margins: root._pad }

                Text {
                    text: "Uptime"
                    font { pixelSize: 13; weight: Font.Medium }
                    color: Colors.md3.on_surface_variant
                    Layout.fillWidth: true
                }

                Text {
                    text: Services.SystemService.uptime ?? "N/A"
                    font { pixelSize: 14; weight: Font.Medium }
                    color: Colors.md3.on_surface
                }
            }
        }

        Item { Layout.fillHeight: true }   // spacer
    }

    // ══════════════════════════════════════════════════════════════
    // Componentes inline
    // ══════════════════════════════════════════════════════════════

    // ── CpuArc (canvas donut) ─────────────────────────────────────
    component CpuArc: Item {
        id: _arc
        property real value: 0.0    // 0–1
        property int  size:  72

        implicitWidth:  size
        implicitHeight: size

        onValueChanged: canvas.requestPaint()

        Canvas {
            id: canvas
            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                const cx    = width  / 2
                const cy    = height / 2
                const r     = (Math.min(width, height) / 2) - 6
                const start = -Math.PI / 2             // 12 en punto
                const end   = start + 2 * Math.PI * _arc.value

                // Track
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.strokeStyle = Colors.md3.surface_container.toString()
                ctx.lineWidth   = 8
                ctx.lineCap     = "round"
                ctx.stroke()

                // Arco activo
                if (_arc.value > 0) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, start, end)
                    ctx.strokeStyle = Colors.md3.primary.toString()
                    ctx.lineWidth   = 8
                    ctx.lineCap     = "round"
                    ctx.stroke()
                }
            }

            // Re-pinta cuando cambian los colores del tema
            Connections {
                target: Colors
                function onPrimaryChanged()            { canvas.requestPaint() }
                function onSurface_containerChanged()  { canvas.requestPaint() }
            }
        }

        // Porcentaje en el centro del donut
        Text {
            anchors.centerIn: parent
            text:  Math.round(_arc.value * 100) + "%"
            font { pixelSize: 13; weight: Font.Bold }
            color: Colors.md3.primary
        }

        // Animación del value para el canvas
        Behavior on value {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }
}
