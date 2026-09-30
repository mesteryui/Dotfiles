// SettingsFieldLabel — etiqueta de campo de ajustes.
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

StyledText {
    font.pixelSize: Appearance.typeScale.titleSmall
    color: Appearance.md3.on_surface_variant
    Layout.fillWidth: true
    elide: Text.ElideRight
}
