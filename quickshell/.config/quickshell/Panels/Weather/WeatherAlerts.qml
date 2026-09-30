// --- WeatherAlerts: píldora de avisos MeteoAlarm + detalle expandible ---
// Visible solo si hay avisos amarillos o superiores para la zona.
// Reutilizable en el popup y en la pestaña del panel.
pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    spacing: Appearance.spacing.s
    visible: Services.WeatherService.data.alertLevel >= 2

    function levelColor() {
        return Services.WeatherService.data.alertLevel >= 3 ? Appearance.md3.error : Appearance.md3.tertiary;
    }

    function levelLabel() {
        const level = Services.WeatherService.data.alertLevel;
        if (level >= 4)
            return Services.I18nService.getTranslation("weather.alert_red", "Aviso rojo");
        if (level === 3)
            return Services.I18nService.getTranslation("weather.alert_orange", "Aviso naranja");
        return Services.I18nService.getTranslation("weather.alert_yellow", "Aviso amarillo");
    }

    function shortDateTime(iso) {
        const s = String(iso ?? "");
        if (s.length < 16)
            return s;
        return s.slice(8, 10) + "/" + s.slice(5, 7) + " " + s.slice(11, 16);
    }

    property bool expanded: false

    // ── Píldora ──────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: Appearance.shape.normal
        color: Qt.alpha(root.levelColor(), 0.16)
        border.width: 1
        border.color: Qt.alpha(root.levelColor(), 0.5)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: Appearance.spacing.s

            MaterialIcon {
                icon: "warning"
                size: 20
                color: root.levelColor()
            }

            StyledText {
                Layout.fillWidth: true
                text: root.levelLabel() + (Services.WeatherService.data.alertCount > 1 ? " · " + Services.WeatherService.data.alertCount : "")
                font.pixelSize: Appearance.typeScale.titleSmall
                font.weight: Font.Medium
                color: Appearance.md3.on_surface
                elide: Text.ElideRight
            }

            MaterialIcon {
                icon: root.expanded ? "expand_less" : "expand_more"
                size: 20
                color: Appearance.md3.on_surface_variant
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Detalle ──────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: root.expanded

        StyledText {
            text: Services.I18nService.getTranslation("weather.alerts_title", "Avisos meteorológicos")
            font.pixelSize: Appearance.typeScale.titleSmall
            font.weight: Font.Bold
            color: Appearance.md3.on_surface
        }

        Repeater {
            model: Services.WeatherService.data.alerts

            ColumnLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: modelData.event
                    font.pixelSize: Appearance.typeScale.titleSmall
                    font.weight: Font.Medium
                    color: Appearance.md3.on_surface
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: modelData.area + " · " + Services.I18nService.getTranslation("weather.alert_from", "desde %1").arg(root.shortDateTime(modelData.onset)) + " " + Services.I18nService.getTranslation("weather.alert_until", "hasta %1").arg(root.shortDateTime(modelData.expires))
                    font.pixelSize: Appearance.typeScale.labelSmall
                    color: Appearance.md3.on_surface_variant
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: (modelData.description ?? "") !== ""
                    text: modelData.description
                    font.pixelSize: Appearance.typeScale.labelSmall
                    color: Appearance.md3.on_surface_variant
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
            }
        }
    }
}
