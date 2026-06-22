import QtQuick
import qs.Core
import qs.Primitives
Item {
    id: root
    property string iconName
    property string text
    implicitHeight: 30
    implicitWidth: volumeLayout.childrenRect.width
    Row {
        id: volumeLayout
        spacing: 8
        anchors.centerIn: parent

        MaterialIcon {
            id: volumeIcon
            size: 20
            color: Colors.md3.on_surface
            icon: root.iconName
        }

        Text {
            id: volumeLabel
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: Colors.md3.on_surface
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }
}