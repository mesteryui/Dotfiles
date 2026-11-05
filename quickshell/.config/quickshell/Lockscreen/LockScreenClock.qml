import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import Quickshell

// Reloj expresivo estilo Pixel / Material You.
// large  = etapa dormida (hero clock). compact = etapa auth (pequeño).
// Cada instancia tiene su propio SystemClock: no depende de TimeService.
ColumnLayout {
    id: root
    Layout.alignment: Qt.AlignHCenter

    spacing: 2

    property bool compact: false

    // SystemClock propio para el reloj del lockscreen: precisión minutos.
    // Entrega ticks incluso mientras la pantalla está bloqueada.
    SystemClock {
        id: clockLock
        precision: SystemClock.Minutes
    }

    readonly property int hours: clockLock.date.getHours()
    readonly property int minutes: clockLock.date.getMinutes()

    function pad(n) { return n < 10 ? "0" + n : n; }

    // Fecha arriba estilo Pixel ("At a Glance"), con clima.
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Appearance.spacing.small

        StyledText {
            id: dateText
            Layout.alignment: Qt.AlignVCenter

            color: Appearance.md3.on_surface_variant
            opacity: 0.95
            font.pixelSize: root.compact ? Appearance.typeScale.titleSmall : Appearance.font.pixelSize.large
            font.variableAxes: Appearance.font.variableAxes.title
            font.family: Appearance.font.sans

            text: root.compact
                ? clockLock.date.toLocaleDateString(Qt.locale(), "ddd, d MMM")
                : clockLock.date.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
        }

        // Clima "At a Glance" estilo Pixel: icono + temperatura.
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Appearance.spacing.extraSmall
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
                font.pixelSize: root.compact ? Appearance.typeScale.titleSmall :
                                               Appearance.font.pixelSize.large
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
        // Números tabulares: el ancho no salta al cambiar de minuto.
        font.features: ({
                        "tnum": 1
                    })
        lineHeight: 1.0

        // Reloj del lockscreen con SystemClock propio: "14:32"
        text: root.pad(root.hours) + ":" + root.pad(root.minutes)
    }
}
