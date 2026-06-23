import QtQuick
import qs.Core.Services
import qs.Core
Text {
    id: root
    renderType: Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    font {
        hintingPreference: Font.PreferDefaultHinting
        family: ConfigService.configs.appearence.fontSans
        pixelSize: 15
    }
    color: Colors.md3.on_background
    linkColor: Colors.md3.primary
}