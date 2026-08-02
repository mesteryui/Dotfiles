// SysInfoTab — Tab de información del sistema.
// Métricas compactas estilo Material You con mejor jerarquía visual.

import QtQuick
import QtQuick.Layouts
import qs.Primitives
import qs.Core.Services as Services
import qs.Core

Item {
    id: root
    implicitWidth:  mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight

    function fmtMem(mib) {
        return mib >= 1024
            ? (mib / 1024).toFixed(1) + " GiB"
            : mib + " MiB"
    }

    function withAlpha(hex, a) {
        const c = Qt.color(hex)
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    ColumnLayout {
        id: mainColumn
        anchors { top: parent.top; left: parent.left; right: parent.right }
        spacing: 8

        // ══ CPU ═══════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            height: 72
            radius: Appearance.shape.normal
            color: Appearance.md3.surface_container_high

            RowLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 14

                // Arco CPU
                CpuArc {
                    size: 52
                    value: Services.SystemInfoService.cpuUsage
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: "CPU"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface_variant
                            Layout.fillWidth: true
                        }

                        // Chip de temperatura
                        Rectangle {
                            implicitWidth: tempLabel.implicitWidth + 12
                            height: 18
                            radius: Appearance.shape.full
                            color: root.withAlpha(Appearance.md3.tertiary_container, 0.85)
                            StyledText {
                                id: tempLabel
                                anchors.centerIn: parent
                                text: Services.SystemInfoService.cpuTemp + "°C"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_tertiary_container
                            }
                        }

                        // Chip de núcleos
                        Rectangle {
                            implicitWidth: coresLabel.implicitWidth + 12
                            height: 18
                            radius: Appearance.shape.full
                            color: root.withAlpha(Appearance.md3.surface_container_highest, 0.9)
                            StyledText {
                                id: coresLabel
                                anchors.centerIn: parent
                                text: Services.SystemInfoService.cpuCores + " " + Services.I18nService.getTranslation("panel.cores", "cores")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.cpuUsage ?? 0
                        accentColor: Appearance.md3.primary
                        implicitHeight: 5
                    }
                }
            }
        }

        // ══ RAM + SWAP ════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // RAM
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: Appearance.shape.normal
                color: Appearance.md3.surface_container_high

                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: "RAM"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface_variant
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: Services.SystemInfoService.memUsagePct ?? "0%"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: Appearance.md3.primary
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.memUsage ?? 0
                        accentColor: Appearance.md3.primary
                        implicitHeight: 5
                    }

                    StyledText {
                        text: root.fmtMem(Services.SystemInfoService.memUsedMiB ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                    }
                }
            }

            // SWAP
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: Appearance.shape.normal
                color: Appearance.md3.surface_container_high
                opacity: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0 ? 1 : 0.45
                Behavior on opacity { NumberAnimation { duration: 300 } }

                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: "Swap"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface_variant
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0
                                ? Math.round((Services.SystemInfoService.swapUsage ?? 0) * 100) + "%"
                                : "—"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: Appearance.md3.secondary
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.swapUsage ?? 0
                        accentColor: Appearance.md3.secondary
                        implicitHeight: 5
                    }

                    StyledText {
                        text: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0
                            ? root.fmtMem(Services.SystemInfoService.swapUsedMiB ?? 0)
                            : Services.I18nService.getTranslation("panel.off", "Off")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ══ DISCO ══════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            height: 60
            radius: Appearance.shape.normal
            color: Appearance.md3.surface_container_high

            RowLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 12

                MaterialIcon {
                    icon: "hard_drive"
                    size: Appearance.font.pixelSize.large
                    color: Appearance.md3.on_surface_variant
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: Services.I18nService.getTranslation("panel.disk", "Disco") + " (/)"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface_variant
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: Services.SystemInfoService.diskUsagePct ?? "0%"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: Appearance.md3.primary
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.diskUsage ?? 0
                        accentColor: Appearance.md3.primary
                        implicitHeight: 5
                    }
                }
            }
        }

        // ══ UPTIME ═════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: Appearance.shape.normal
            color: root.withAlpha(Appearance.md3.surface_container, 0.7)

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 8

                MaterialIcon {
                    icon: "schedule"
                    size: Appearance.font.pixelSize.normal
                    color: Appearance.md3.on_surface_variant
                }
                StyledText {
                    text: Services.I18nService.getTranslation("panel.uptime", "Uptime")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: Appearance.md3.on_surface_variant
                    Layout.fillWidth: true
                }
                StyledText {
                    text: Services.SystemInfoService.uptime ?? "N/A"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: Appearance.md3.on_surface
                }
            }
        }
    }
}
