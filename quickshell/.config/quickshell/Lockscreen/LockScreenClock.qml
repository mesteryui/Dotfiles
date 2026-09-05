import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    Layout.alignment: Qt.AlignHCenter

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    StyledText {
        id: clockText
        Layout.alignment: Qt.AlignHCenter

        color: Appearance.md3.on_surface
        opacity: 0.9
        font.pixelSize: Appearance.font.pixelSize.hugeass + 70
        font.variableAxes: Appearance.font.variableAxes.title

        text: clock.date.toLocaleTimeString(I18nService.locale, "hh:mm")
    }

    StyledText {
        id: dateText
        Layout.alignment: Qt.AlignHCenter

        color: Appearance.md3.on_surface
        opacity: 0.92
        font.pixelSize: Appearance.font.pixelSize.normal
        font.variableAxes: Appearance.font.variableAxes.title

        text: clock.date.toLocaleDateString(I18nService.locale, "ddd dd MMM yyyy")
    }
}
