import QtQuick.Controls
import QtQuick
import qs.Core
TextArea {
    renderType: Text.NativeRendering
    placeholderTextColor: Appearance.md3.outline
    selectionColor: Appearance.md3.on_secondary_container
    selectedTextColor: Appearance.md3.secondary_container
    color: Appearance.md3.surface
    font {
        family: Appearance.font.sans
        pixelSize: Appearance.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
        variableAxes: Appearance.font.variableAxes.main
    }
}