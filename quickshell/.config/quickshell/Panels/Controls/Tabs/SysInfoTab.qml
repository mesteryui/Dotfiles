import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Primitives
import qs.Core.Services as Services
import qs.Core

Item {
    id: root
    implicitWidth: mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight

    // ── Tokens ────────────────────────────────────────────────────
    readonly property int _pad: 20
    readonly property int _gap: 12

    // ── Helper: formatea MiB → "X.X GiB" o "XXX MiB" ────────────
    function fmtMem(mib) {
        return mib >= 1024
            ? (mib / 1024).toFixed(1) + " GiB"
            : mib + " MiB"
    }

    // ─────────────────────────────────────────────────────────────
    ColumnLayout {
        id: mainColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
        }
        spacing: root._gap

        // ══ CPU Card ══════════════════════════════════════════════
        M3Card {
            Layout.fillWidth: true
            padding: root._pad

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 16

                // Donut / arc de uso
                CpuArc {
                    id: cpuArc
                    size: 72
                    value: Services.SystemInfoService.cpuUsage
                }

                // Textos
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Header: CPU + badge de temperatura
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "CPU"
                            font {
                                family: Services.ConfigService.getConfig("fontSans","sans-serif")
                                pixelSize: 11
                                weight: Font.Medium
                                letterSpacing: 0.8
                            }
                            color: Colors.md3.on_surface_variant
                        }

                        Item { Layout.fillWidth: true }

                        // Chip de temperatura
                        Rectangle {
                            implicitWidth: tempLabel.implicitWidth + 14
                            implicitHeight: 20
                            radius: 9999
                            color: Colors.md3.tertiary_container

                            Text {
                                id: tempLabel
                                anchors.centerIn: parent
                                text: Services.SystemInfoService.cpuTemp + "°C"
                                font {
                                    family: Services.ConfigService.getConfig("fontSans","sans-serif")
                                    pixelSize: 10
                                    weight: Font.Medium
                                }
                                color: Colors.md3.on_tertiary_container
                            }
                        }
                    }

                    // Porcentaje grande
                    Text {
                        text: Services.SystemInfoService.cpuUsagePct ?? "0%"
                        font {
                            family: Services.ConfigService.getConfig("fontSans","sans-serif")
                            pixelSize: 24
                            weight: Font.Bold
                        }
                        color: Colors.md3.primary
                    }

                    // Barra de progreso
                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.cpuUsage ?? 0
                        accentColor: Colors.md3.primary
                        implicitHeight: 6
                    }

                    Text {
                        text: Services.SystemInfoService.cpuCores + " " + Services.I18nService.getTranslation("panel.cores", "núcleos")
                        font {
                            family: Services.ConfigService.getConfig("fontSans","sans-serif")
                            pixelSize: 10
                        }
                        color: Colors.md3.on_surface_variant
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
                padding: root._pad

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "RAM"
                            font {
                                family: Services.ConfigService.getConfig("fontSans","sans-serif")
                                pixelSize: 11
                                weight: Font.Medium
                                letterSpacing: 0.8
                            }
                            color: Colors.md3.on_surface_variant
                            Layout.fillWidth: true
                        }
                        Text {
                            text: Services.SystemInfoService.memUsagePct ?? "0%"
                            font {
                                family: Services.ConfigService.getConfig("font")
                                pixelSize: 13
                                weight: Font.Bold
                            }
                            color: Colors.md3.primary
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.memUsage ?? 0
                        accentColor: Colors.md3.primary
                        implicitHeight: 6
                    }

                    Text {
                        text: fmtMem(Services.SystemInfoService.memUsedMiB ?? 0)
                        font {
                            family: Services.ConfigService.getConfig("fontSans","sans-serif")
                            pixelSize: 10
                        }
                        color: Colors.md3.on_surface_variant
                        elide: Text.ElideRight
                    }
                }
            }

            // ── Swap ─────────────────────────────────────────────
            M3Card {
                Layout.fillWidth: true
                padding: root._pad
                opacity: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0 ? 1.0 : 0.45
                Behavior on opacity { NumberAnimation { duration: 300 } }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Swap"
                            font {
                                family: Services.ConfigService.getConfig("fontSans","sans-serif")
                                pixelSize: 11
                                weight: Font.Medium
                                letterSpacing: 0.8
                            }
                            color: Colors.md3.on_surface_variant
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0
                                ? Math.round((Services.SystemInfoService.swapUsage ?? 0) * 100) + "%"
                                : "—"
                            font {
                                family: Services.ConfigService.getConfig("fontSans","sans-serif")
                                pixelSize: 13
                                weight: Font.Bold
                            }
                            color: Colors.md3.secondary
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.swapUsage ?? 0
                        accentColor: Colors.md3.secondary
                        implicitHeight: 6
                    }

                    Text {
                        text: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0
                            ? fmtMem(Services.SystemInfoService.swapUsedMiB ?? 0)
                            : Services.I18nService.getTranslation("panel.off", "Off")
                        font {
                            family: Services.ConfigService.getConfig("fontSans","sans-serif")
                            pixelSize: 10
                        }
                        color: Colors.md3.on_surface_variant
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ══ Disk Card ═════════════════════════════════════════════
        M3Card {
            Layout.fillWidth: true
            padding: root._pad

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: Services.I18nService.getTranslation("panel.disk", "Disco") + " (/)"
                        font {
                            family: Services.ConfigService.getConfig("fontSans","sans-serif")
                            pixelSize: 11
                            weight: Font.Medium
                            letterSpacing: 0.8
                        }
                        color: Colors.md3.on_surface_variant
                        Layout.fillWidth: true
                    }
                    Text {
                        text: Services.SystemInfoService.diskUsagePct ?? "0%"
                        font {
                            family: Services.ConfigService.getConfig("fontSans","sans-serif")
                            pixelSize: 13
                            weight: Font.Bold
                        }
                        color: Colors.md3.primary
                    }
                }

                M3ProgressBar {
                    Layout.fillWidth: true
                    value: Services.SystemInfoService.diskUsage ?? 0
                    accentColor: Colors.md3.primary
                    implicitHeight: 6
                }

                Text {
                    text: (Services.SystemInfoService.diskUsed ?? "0") + " " +
                          Services.I18nService.getTranslation("panel.of", "de") + " " +
                          (Services.SystemInfoService.diskTotal ?? "0")
                    font {
                        family: Services.ConfigService.getConfig("fontSans","sans-serif")
                        pixelSize: 10
                    }
                    color: Colors.md3.on_surface_variant
                    elide: Text.ElideRight
                }
            }
        }

        // ══ Uptime Card ═══════════════════════════════════════════
        M3Card {
            Layout.fillWidth: true
            padding: root._pad

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                MaterialIcon {
                    icon: "schedule"
                    size: 16
                    color: Colors.md3.on_surface_variant
                }

                Text {
                    text: Services.I18nService.getTranslation("panel.uptime", "Uptime")
                    font {
                        family: Services.ConfigService.getConfig("fontSans","sans-serif")
                        pixelSize: 11
                        weight: Font.Medium
                        letterSpacing: 0.8
                    }
                    color: Colors.md3.on_surface_variant
                    Layout.fillWidth: true
                }

                Text {
                    text: Services.SystemInfoService.uptime ?? "N/A"
                    font {
                        family: Services.ConfigService.getConfig("font")
                        pixelSize: 12
                        weight: Font.Bold
                    }
                    color: Colors.md3.on_surface
                }
            }
        }
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
                const start = -Math.PI / 2
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

            Connections {
                target: Colors.md3
                function onPrimaryChanged()           { canvas.requestPaint() }
                function onSurface_containerChanged() { canvas.requestPaint() }
            }
        }

        // Porcentaje en el centro del donut
        Text {
            anchors.centerIn: parent
            text: Math.round(_arc.value * 100) + "%"
            font {
                family: Services.ConfigService.getConfig("fontSans","sans-serif")
                pixelSize: 13
                weight: Font.Bold
            }
            color: Colors.md3.primary
        }

        Behavior on value {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }
}
