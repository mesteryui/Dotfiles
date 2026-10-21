// SettingsTextRow — campo de texto con etiqueta.
// Extraído de SettingsPanelContent.qml.
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: textRow

    property string label: ""
    property string value: ""

    signal edited(string text)

    Layout.fillWidth: true
    spacing: Appearance.spacing.extraSmall

    SettingsFieldLabel {
        text: textRow.label
    }
    MaterialTextField {
        Layout.fillWidth: true
        text: textRow.value
        onEditingFinished: textRow.edited(text)
    }
}
