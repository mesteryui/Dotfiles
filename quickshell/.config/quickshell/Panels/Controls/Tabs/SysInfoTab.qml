// SysInfoTab — Content
// Tab de información del sistema. No tiene Background propio —
// vive dentro del Background del ControlPanel.

import QtQuick
import QtQuick.Layouts
import qs.Primitives
import qs.Core.Services as Services
import qs.Core

Item {
    id: root
    implicitWidth:  mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight

    readonly property int _pad: 20
    readonly property int _gap: 12

    function fmtMem(mib) {
        return mib >= 1024
            ? (mib / 1024).toFixed(1) + " GiB"
            : mib + " MiB"
    }

    ColumnLayout {
        id: mainColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
        }
        spacing: root._gap

        // ══ CPU ═══════════════════════════════════════════════════
        M3Card {
            Layout.fillWidth: true
            padding: root._pad

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 16

                CpuArc {
                    size: 72
                    value: Services.SystemInfoService.cpuUsage
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            text: "CPU"
                            font {
                                family: Services.ConfigService.configs.appearence.fontSans
                                pixelSize: 11
                                weight: Font.Medium
                                letterSpacing: 0.8
                            }
                            color: Appearance.md3.on_surface_variant
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: tempLabel.implicitWidth + 14
                            implicitHeight: 20
                            radius: Appearance.shape.full
                            color: Appearance.md3.tertiary_container

                            StyledText {
                                id: tempLabel
                                anchors.centerIn: parent
                                text: Services.SystemInfoService.cpuTemp + "°C"
                                font {
                                    family: Services.ConfigService.configs.appearence.fontSans
                                    pixelSize: 10
                                    weight: Font.Medium
                                }
                                color: Appearance.md3.on_tertiary_container
                            }
                        }
                    }

                    StyledText {
                        text: Services.SystemInfoService.cpuUsagePct ?? "0%"
                        font {
                            family: Services.ConfigService.configs.appearence.fontSans
                            pixelSize: 24
                            weight: Font.Bold
                        }
                        color: Appearance.md3.primary
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.cpuUsage ?? 0
                        accentColor: Appearance.md3.primary
                        implicitHeight: 6
                    }

                    StyledText {
                        text: Services.SystemInfoService.cpuCores + " "
                            + Services.I18nService.getTranslation("panel.cores", "núcleos")
                        font {
                            family: Services.ConfigService.configs.appearence.fontSans
                            pixelSize: 10
                        }
                        color: Appearance.md3.on_surface_variant
                    }
                }
            }
        }

        // ══ RAM + Swap ════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: root._gap

            M3Card {
                Layout.fillWidth: true
                padding: root._pad

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: "RAM"
                            font {
                                family: Services.ConfigService.configs.appearence.fontSans
                                pixelSize: 11
                                weight: Font.Medium
                                letterSpacing: 0.8
                            }
                            color: Appearance.md3.on_surface_variant
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: Services.SystemInfoService.memUsagePct ?? "0%"
                            font {
                                family: Services.ConfigService.configs.appearence.fontSans
                                pixelSize: 13
                                weight: Font.Bold
                            }
                            color: Appearance.md3.primary
                        }
                    }

                    M3ProgressBar {
                        Layout.fillWidth: true
                        value: Services.SystemInfoService.memUsage ?? 0
                        accentColor: Appearance.md3.primary
                        implicitHeight: 6
                    }

                    StyledText {
                        text: root.fmtMem(Services.SystemInfoService.memUsedMiB ?? 0)
                        font {
                            family: Services.ConfigService.configs.appearence.fontSans
                            pixelSize: 10
                        }
                        color: Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                    }
                }
            }

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
                        StyledText {
                            text: "Swap"
                            font {
                                family: Services.ConfigService.configs.appearence.fontSans
                                pixelSize: 11
                                weight: Font.Medium
                                letterSpacing: 0.8
                            }
                            color: Appearance.md3.on_surface_variant
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: (Services.SystemInfoService.swapTotalMiB ?? 0) > 0
                                ? Math.round((Services.SystemInfoService.swapUsage ?? 0) * 100) + "%"
                                : "—"
                            font {
                                family: Services.ConfigService.configs.appearence.fontSans
                                pixelSize: 13
                                weight: Font.Bold
                            }
                            color: Appearance.md3.secondary
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
                            ? root.fmtMem(Services.SystemInfoService.swapUsedMiB ?? 0)
                            : Services.I18nService.getTranslation("panel.off", "Off")
                        font {
                            family: Services.ConfigService.configs.appearence.fontSans
                            pixelSize: 10
                        }
                        color: Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ══ Disco ═════════════════════════════════════════════════
        M3Card {
            Layout.fillWidth: true
            padding: root._pad

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Services.I18nService.getTranslation("panel.disk", "Disco") + " (/)"
                        font {
                            family: Services.ConfigService.configs.appearence.fontSans
                            pixelSize: 11
                            weight: Font.Medium
                            letterSpacing: 0.8
                        }
                        color: Appearance.md3.on_surface_variant
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: Services.SystemInfoService.diskUsagePct ?? "0%"
                        font {
                            family: Services.ConfigService.configs.appearence.fontSans
                            pixelSize: 13
                            weight: Font.Bold
                        }
                        color: Appearance.md3.primary
                    }
                }

                M3ProgressBar {
                    Layout.fillWidth: true
                    value: Services.SystemInfoService.diskUsage ?? 0
                    accentColor: Appearance.md3.primary
                    implicitHeight: 6
                }

                StyledText {
                    text: (Services.SystemInfoService.diskUsed ?? "0") + " "
                        + Services.I18nService.getTranslation("panel.of", "de") + " "
                        + (Services.SystemInfoService.diskTotal ?? "0")
                    font {
                        family: Services.ConfigService.configs.appearence.fontSans
                        pixelSize: 10
                    }
                    color: Appearance.md3.on_surface_variant
                    elide: Text.ElideRight
                }
            }
        }

        // ══ Uptime ════════════════════════════════════════════════
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
                    color: Appearance.md3.on_surface_variant
                }

                StyledText {
                    text: Services.I18nService.getTranslation("panel.uptime", "Uptime")
                    font {
                        family: Services.ConfigService.configs.appearence.fontSans
                        pixelSize: 11
                        weight: Font.Medium
                        letterSpacing: 0.8
                    }
                    color: Appearance.md3.on_surface_variant
                    Layout.fillWidth: true
                }

                StyledText {
                    text: Services.SystemInfoService.uptime ?? "N/A"
                    font {
                        family: Services.ConfigService.configs.appearence.fontSans
                        pixelSize: 12
                        weight: Font.Bold
                    }
                    color: Appearance.md3.on_surface
                }
            }
        }
    }
}
