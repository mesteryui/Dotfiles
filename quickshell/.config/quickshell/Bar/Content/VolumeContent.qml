import qs.Core
import qs.Primitives
import QtQuick

Item {
    id: root

    property string icon
    property string text

    implicitHeight: 30
    implicitWidth: volumeLayout.childrenRect.width

    Row {
        id: volumeLayout

        spacing: Appearance.spacing.small
        anchors.centerIn: parent

        MaterialIcon {
            id: volumeIcon

            size: Appearance.font.pixelSize.larger
            color: Appearance.md3.on_surface
            icon: root.icon
        }

        StyledText {
            id: volumeLabel

            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: Appearance.md3.on_surface
            font.pixelSize: Appearance.typeScale.bodyMedium
        }
    }
}
