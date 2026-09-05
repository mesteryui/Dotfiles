import qs.Core
import qs.Primitives
import QtQuick

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

            size: Appearance.font.pixelSize.larger
            color: Appearance.md3.on_surface
            icon: root.iconName
        }

        StyledText {
            id: volumeLabel

            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: Appearance.md3.on_surface
            font.pixelSize: 14
        }
    }
}