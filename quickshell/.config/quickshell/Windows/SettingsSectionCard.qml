// SettingsSectionCard — tarjeta de sección de ajustes.
// Extraído de SettingsPanelContent.qml para partir sus ~950 líneas.
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

M3Card {
    id: card

    property string title: ""
    default property alias rows: inner.data

    Layout.fillWidth: true
    padding: 16
    color: Appearance.md3.surface_container_high

    content: ColumnLayout {
        id: inner

        width: parent.width
        spacing: 14

        StyledText {
            text: card.title
            font.pixelSize: Appearance.typeScale.titleSmall
            font.weight: Font.Medium
            font.variableAxes: Appearance.font.variableAxes.title
            color: Appearance.md3.primary
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}
