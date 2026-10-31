// CheatsheetCategoryTab — pestaña lateral del cheatsheet (navigation-drawer M3).
// Muestra la categoría, su icono y el número de atajos que contiene.
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string category: ""
    property string icon: "keyboard"
    property int count: 0
    property bool selected: false

    Accessible.role: Accessible.PageTab
    Accessible.name: root.category + " (" + root.count + ")"
    Accessible.selected: root.selected

    signal clicked

    Layout.fillWidth: true
    implicitHeight: 46
    radius: Appearance.shape.full
    color: root.selected ? Appearance.md3.secondary_container : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Appearance.motion.fast
        }
    }

    M3StateLayer {
        anchors.fill: parent
        radius: parent.radius
        tint: root.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
        hovered: tabArea.containsMouse
        pressed: tabArea.pressed
    }

    RowLayout {
        anchors.fill: parent
        anchors {
            leftMargin: Appearance.spacing.medium
            rightMargin: Appearance.spacing.small
        }

        spacing: Appearance.spacing.small

        MaterialIcon {
            icon: root.icon
            size: 18
            color: root.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
        }

        StyledText {
            Layout.fillWidth: true
            text: root.category
            color: root.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
            font.pixelSize: Appearance.typeScale.bodyMedium
            font.variableAxes: root.selected ? Appearance.font.variableAxes.title :
                                               Appearance.font.variableAxes.main
            elide: Text.ElideRight
        }

        Rectangle {
            implicitWidth: Math.max(24, countLabel.implicitWidth + 12)
            implicitHeight: 20
            radius: Appearance.shape.full
            color: root.selected ? Appearance.md3.primary : Appearance.md3.surface_container_highest

            StyledText {
                id: countLabel

                anchors.centerIn: parent
                text: root.count
                color: root.selected ? Appearance.md3.on_primary : Appearance.md3.on_surface_variant
                font.pixelSize: Appearance.typeScale.labelSmall
                font.variableAxes: Appearance.font.variableAxes.numbers
            }
        }
    }

    MouseArea {
        id: tabArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
