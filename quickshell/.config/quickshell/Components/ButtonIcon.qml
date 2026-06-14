import Quickshell
import QtQuick
import Quickshell.Widgets
import ".."

Item {
    id: root

    required property string iconName
    signal clicked
    property int size: 16
    property color iconColor: Colors.on_surface

    implicitWidth: size
    implicitHeight: size

    opacity: enabled ? 1.0 : 0.38
    Behavior on opacity { NumberAnimation { duration: 150 } }

    IconImage {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        source: Quickshell.iconPath(root.iconName)

        // Tinte del icono si el theme lo requiere
        layer.enabled: false
    }

    scale: mouse.pressed ? 1.20 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}