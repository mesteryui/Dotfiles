import qs.Core
import QtQuick

Item {
    id: root

    required property string iconName

    property int iconSize: 16

    property color iconColor: Appearance.md3.on_surface

    property int padding: 4

    signal clicked

    // Dimensiones implícitas que incluyen el padding para la zona interactiva
    implicitWidth: iconSize + (padding * 2)
    implicitHeight: iconSize + (padding * 2)

    opacity: enabled ? 1.0 : 0.38

    Behavior on opacity { NumberAnimation { duration: 150 } }

    MaterialIcon {
        id: iconItem

        anchors.centerIn: parent
        icon: root.iconName
        size: root.iconSize
        color: root.iconColor
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
