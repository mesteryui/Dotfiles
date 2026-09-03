import QtQuick
import qs.Core
import QtQuick.Controls.Material
import QtQuick.Controls

TextField {
    id: root
    Material.theme: Material.System
    Material.accent: Appearance.md3.primary
    Material.primary: Appearance.md3.primary
    Material.background: Appearance.md3.surface
    Material.foreground: Appearance.md3.on_surface
    Material.containerStyle: Material.Outlined
    renderType: Text.QtRendering
    wrapMode: TextEdit.Wrap
    selectedTextColor: Appearance.md3.on_secondary_container
    selectionColor: Appearance.md3.secondary_container
    placeholderTextColor: Appearance.md3.outline
    clip: true

    font {
        family: Appearance.font.sans
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
        variableAxes: Appearance.font.variableAxes.main
    }
}
