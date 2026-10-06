import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick

Item {
    id: root

    implicitWidth: clockText.implicitWidth
    implicitHeight: clockText.implicitHeight

    StyledText {
        id: clockText

        font.family: Services.ConfigService.configs.appearance.fontSans
        color: Appearance.md3.on_surface
        font.pixelSize: Appearance.typeScale.titleSmall

        // Reloj único del shell (TimeService): "mar 14:32".
        text: Services.TimeService.barText
    }
}
