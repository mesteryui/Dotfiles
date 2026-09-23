import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import Quickshell

// Reloj expresivo estilo Pixel / Material You.
// large  = etapa dormida (hero clock). compact = etapa auth (pequeño).
ColumnLayout {
    id: root
    Layout.alignment: Qt.AlignHCenter
    spacing: 2

    property bool compact: false

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Fecha arriba estilo Pixel ("At a Glance"), con clima.
    // (Se probó también un sol/luna de día/noche, pero duplicaba
    // visualmente el icono de condición del clima.)
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        StyledText {
            id: dateText
            Layout.alignment: Qt.AlignVCenter

            color: Appearance.md3.on_surface_variant
            opacity: 0.95
            font.pixelSize: root.compact ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.large
            font.variableAxes: Appearance.font.variableAxes.title
            font.family: Appearance.font.sans

            text: root.compact ? clock.date.toLocaleDateString(I18nService.locale, "ddd, d MMM") : clock.date.toLocaleDateString(I18nService.locale, "dddd, d MMMM")
        }

        // Clima "At a Glance" estilo Pixel: icono + temperatura.
        // Oculto hasta que el servicio tenga datos reales.
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 4
            visible: WeatherService.data.temp !== "--°C"

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: WeatherService.icon
                size: root.compact ? 16 : 22
                color: Appearance.md3.primary
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: WeatherService.data.temp
                color: Appearance.md3.on_surface_variant
                opacity: 0.95
                font.pixelSize: root.compact ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.large
                font.variableAxes: Appearance.font.variableAxes.title
                font.family: Appearance.font.sans
            }
        }
    }

    StyledText {
        id: clockText
        Layout.alignment: Qt.AlignHCenter

        color: Appearance.md3.on_surface
        opacity: 0.96
        font.pixelSize: root.compact ? 54 : 124
        font.variableAxes: Appearance.font.variableAxes.title
        font.family: Appearance.font.expressive
        font.weight: root.compact ? Font.DemiBold : Font.Bold
        lineHeight: 1.0

        text: clock.date.toLocaleTimeString(I18nService.locale, "hh:mm")
    }
}
