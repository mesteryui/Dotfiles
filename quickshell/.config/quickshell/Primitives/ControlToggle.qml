import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Core

Rectangle {
    id: root

    property string label: ""
    property string iconName: ""
    property bool active: false
    signal toggled

    // Tamaño implícito dinámico
    implicitWidth: Math.max(80, contentColumn.implicitWidth + 32)
    implicitHeight: Math.max(64, contentColumn.implicitHeight + 20)
    
    radius: 14
    color: active
        ? Appearance.md3.secondary_container
        : Appearance.md3.surface_variant

    Behavior on color { ColorAnimation { duration: 150 } }

    border.width: 1
    border.color: active
        ? Qt.alpha(Appearance.md3.primary, 0.5)
        : Appearance.md3.outline_variant

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 6
        
        readonly property real implicitWidth: Math.max(toggleIcon.width, toggleLabel.implicitWidth)
        readonly property real implicitHeight: toggleIcon.height + spacing + toggleLabel.implicitHeight

        MaterialIcon {
            id: toggleIcon
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.iconName
            size: 22
            color: root.active ? Appearance.md3.primary : Appearance.md3.on_surface_variant
        }

        Text {
            id: toggleLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.pixelSize: 11
            color: root.active ? Appearance.md3.primary : Appearance.md3.on_surface_variant
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
