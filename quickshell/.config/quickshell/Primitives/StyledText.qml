import qs.Core.Services
import qs.Core
import QtQuick

Text {
    id: root

    property bool shouldUseNumberFont: /^\d+$/.test(root.text)

    renderType: Text.NativeRendering
    //textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter

    font {
        hintingPreference: Font.PreferDefaultHinting
        family: ConfigService.configs.appearence.fontSans
        pixelSize: Appearance.font.pixelSize.small
        variableAxes: shouldUseNumberFont ? ({}) : Appearance.font.variableAxes.main
    }
    color: Appearance.md3.on_background
    linkColor: Appearance.md3.primary
}
