// SysInfoTab — Tab de información del sistema estilo Material 3 Expressive.
// Versión compacta: cabe sin apenas scroll junto al header del panel.
// Métricas construidas con Primitives.M3Card, M3ProgressBar y MaterialIcon.

import qs.Primitives
import qs.Core.Services as Services
import qs.Core
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight

    // Formateador de memoria en MiB/GiB con precisión decimal
    function fmtMem(mib) {
        const val = mib ?? 0
        return val >= 1024
            ? (val / 1024).toFixed(1) + " GiB"
            : val + " MiB"
    }

    // Color de estado M3 Expressive según porcentaje de uso
    function getUsageColor(val, defaultColor) {
        const usage = val ?? 0
        if (usage > 0.85) return Appearance.md3.error
        if (usage > 0.70) return Appearance.md3.tertiary
        return defaultColor || Appearance.md3.primary
    }

    // Color de estado M3 Expressive según temperatura de CPU
    function getTempColor(temp) {
        const t = temp ?? 0
        if (t > 80) return Appearance.md3.error
        if (t > 65) return Appearance.md3.tertiary
        return Appearance.md3.on_tertiary_container
    }

    function withAlpha(hex, a) {
        const c = Qt.color(hex)
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    ColumnLayout {
        id: mainColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        spacing: 8

        // ══ CPU HERO CARD ═════════════════════════════════════════
        M3Card {
            Layout.fillWidth: true
            padding: 12
            radius: 20
            color: Appearance.md3.surface_container_high

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 12

                // Arco Donut de CPU M3
                CpuArc {
                    size: 42
                    value: Services.SystemInfoService.cpuUsage ?? 0
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialIcon {
                            icon: "memory"
                            size: Appearance.font.pixelSize.normal
                            color: root.getUsageColor(Services.SystemInfoService.cpuUsage, Appearance.md3.primary)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "CPU"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Badge de Temperatura
                        Rectangle {
                            implicitWidth: tempLabel.implicitWidth + 12
                            implicitHeight: 20
                            radius: 10
                            Layout.alignment: Qt.AlignVCenter
                            color: root.withAlpha(root.getTempColor(Services.SystemInfoService.cpuTemp), 0.20)

                            StyledText {
                                id: tempLabel

                                anchors.centerIn: parent
                                text: (Services.SystemInfoService.cpuTemp ?? 0) + "°C"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: root.getTempColor(Services.SystemInfoService.cpuTemp)
                            }
                        }

                        // Badge de Núcleos
                        Rectangle {
                            implicitWidth: coresLabel.implicitWidth + 12
                            implicitHeight: 20
                            radius: 10
                            Layout.alignment: Qt.AlignVCenter
                            color: root.withAlpha(Appearance.md3.surface_container_highest, 0.9)

                            StyledText {
                                id: coresLabel

                                anchors.centerIn: parent
                                text: (Services.SystemInfoService.cpuCores ?? 0) + " " + Services.I18nService.getTranslation("panel.cores", "núcleos")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.md3.on_surface_variant
                            }
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.cpuUsage ?? 0
                        accentColor: root.getUsageColor(Services.SystemInfoService.cpuUsage, Appearance.md3.primary)
                        implicitHeight: 6
                    }
                }
            }
        }

        // ══ RAM + SWAP ════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // RAM Card
            M3Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 10
                radius: 20
                color: Appearance.md3.surface_container_high

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialIcon {
                            icon: "developer_board"
                            size: Appearance.font.pixelSize.normal
                            color: root.getUsageColor(Services.SystemInfoService.memUsage, Appearance.md3.primary)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "RAM"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: Services.SystemInfoService.memUsagePct ?? "0%"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: root.getUsageColor(Services.SystemInfoService.memUsage, Appearance.md3.primary)
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.memUsage ?? 0
                        accentColor: root.getUsageColor(Services.SystemInfoService.memUsage, Appearance.md3.primary)
                        implicitHeight: 6
                    }

                    StyledText {
                        text: root.fmtMem(Services.SystemInfoService.memUsedMiB) + " / " + root.fmtMem(Services.SystemInfoService.memTotalMiB)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // SWAP Card
            M3Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 10
                radius: 20
                color: Appearance.md3.surface_container_high
                opacity: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0 ? 1.0 : 0.50

                Behavior on opacity { NumberAnimation { duration: 300 } }

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialIcon {
                            icon: "swap_horiz"
                            size: Appearance.font.pixelSize.normal
                            color: Appearance.md3.secondary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "Swap"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0
                                ? Math.round((Services.SystemInfoService.swapUsage ?? 0) * 100) + "%"
                                : "—"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Bold
                            color: Appearance.md3.secondary
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.swapUsage ?? 0
                        accentColor: Appearance.md3.secondary
                        implicitHeight: 6
                    }

                    StyledText {
                        text: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0
                            ? root.fmtMem(Services.SystemInfoService.swapUsedMiB) + " / " + root.fmtMem(Services.SystemInfoService.swapTotalMiB)
                            : Services.I18nService.getTranslation("panel.off", "Desactivada")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // ══ DISCO + UPTIME (una sola tarjeta) ═════════════════════
        M3Card {
            Layout.fillWidth: true
            padding: 10
            radius: 20
            color: Appearance.md3.surface_container_high

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialIcon {
                        icon: "hard_drive"
                        size: Appearance.font.pixelSize.large
                        color: root.getUsageColor(Services.SystemInfoService.diskUsage, Appearance.md3.primary)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: Services.I18nService.getTranslation("panel.disk", "Disco") + " (/)"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignBottom
                            }

                            StyledText {
                                text: (Services.SystemInfoService.diskUsed ?? "0G") + " / " + (Services.SystemInfoService.diskTotal ?? "0G") + " (" + (Services.SystemInfoService.diskUsagePct ?? "0%") + ")"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: root.getUsageColor(Services.SystemInfoService.diskUsage, Appearance.md3.primary)
                                Layout.alignment: Qt.AlignBottom
                            }
                        }

                        M3ProgressBar {
                            Layout.fillWidth: true
                            value: Services.SystemInfoService.diskUsage ?? 0
                            accentColor: root.getUsageColor(Services.SystemInfoService.diskUsage, Appearance.md3.primary)
                            implicitHeight: 6
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.withAlpha(Appearance.md3.outline_variant, 0.4)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialIcon {
                        icon: "schedule"
                        size: Appearance.font.pixelSize.normal
                        color: Appearance.md3.primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: Services.I18nService.getTranslation("panel.uptime", "Tiempo activo")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.md3.on_surface_variant
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: Services.SystemInfoService.uptime ?? "N/A"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: Appearance.md3.on_surface
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }
}
