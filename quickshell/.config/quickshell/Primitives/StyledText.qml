import QtQuick
import qs.Core.Services
import qs.Core

Text {
    id: root
    renderType: Text.NativeRendering
    //textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter

    property bool shouldUseNumberFont: /^\d+$/.test(root.text)
    font {
        hintingPreference: Font.PreferDefaultHinting
        family: ConfigService.configs.appearence.fontSans
        pixelSize: 15
        variableAxes: shouldUseNumberFont ? ({}) : Appearance.font.variableAxes.main
    }
    color: Appearance.md3.on_background
    linkColor: Appearance.md3.primary
}
