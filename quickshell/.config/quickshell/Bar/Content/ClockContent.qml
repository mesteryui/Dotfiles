import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import Quickshell

Item {
    id: root

    implicitWidth: clockText.implicitWidth
    implicitHeight: clockText.implicitHeight

    // SystemClock propio para el reloj de la barra: precisión minutos.
    // Qt entrega ticks incluso durante el bloqueo de pantalla.
    SystemClock {
        id: clockBar

        precision: SystemClock.Minutes
    }

    readonly property int hours: clockBar.date.getHours()

    readonly property int minutes: clockBar.date.getMinutes()

    readonly property string weekdayText: clockBar.date.toLocaleDateString(Qt.locale(), "ddd")

    function pad(n) {
        return n < 10 ? "0" + n : n;
    }

    StyledText {
        id: clockText

        font.family: Services.ConfigService.configs.appearance.fontSans
        color: Appearance.md3.on_surface
        font.pixelSize: Appearance.typeScale.titleSmall

        // Reloj de barra con SystemClock propio: "mar 14:32"
        text: root.weekdayText + " " + root.pad(root.hours) + ":" + root.pad(root.minutes)
    }
}
