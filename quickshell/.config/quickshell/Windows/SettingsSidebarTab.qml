// SettingsSidebarTab — pestaña lateral (navigation-drawer M3).
// Extraído de SettingsPanelContent.qml.
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: tabBtn

    property string iconName: ""
    property string title: ""
    property string description: ""
    property bool selected: false

    Accessible.role: Accessible.PageTab
    Accessible.name: title

    signal clicked

    Layout.fillWidth: true
    implicitHeight: 60
    // Spec M3 navigation-drawer: indicador activo en pastilla full.
    radius: Appearance.shape.full
    color: "transparent"

    M3SelectionFill {
        anchors.fill: parent
        radius: parent.radius
        selected: tabBtn.selected
    }

    M3StateLayer {
        anchors.fill: parent
        radius: parent.radius
        tint: tabBtn.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
        hovered: tabArea.containsMouse
        pressed: tabArea.pressed
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: Appearance.spacing.m

        StyledText {
            text: tabBtn.iconName
            font.family: "Material Symbols Rounded"
            font.pixelSize: 22
            color: tabBtn.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                text: tabBtn.title
                font.pixelSize: Appearance.typeScale.bodyLarge
                font.weight: Font.Medium
                color: tabBtn.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            StyledText {
                text: tabBtn.description
                font.pixelSize: Appearance.typeScale.labelMedium
                color: tabBtn.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    MouseArea {
        id: tabArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tabBtn.clicked()
    }
}
