import qs.Core
import QtQuick
import M3Shapes

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

    opacity: enabled ? 1.0 : Appearance.state.disabled

    Behavior on opacity { NumberAnimation { duration: Appearance.motion.short3 } }

    // State layer M3 (icon-button estándar): velo circular al hover/press.
    MaterialShape {
        anchors.centerIn: parent
        width: Math.max(parent.width, parent.height)
        height: width
        shape: MaterialShape.Circle
        color: Appearance.md3.on_surface
        opacity: iconMouse.pressed ? Appearance.state.pressed : (iconMouse.containsMouse ? Appearance.state.hovered : 0.0)

        Behavior on opacity { NumberAnimation { duration: Appearance.motion.short2 } }
    }

    MaterialIcon {
        id: iconItem

        anchors.centerIn: parent
        icon: root.iconName
        size: root.iconSize
        color: root.iconColor
    }

    MouseArea {
        id: iconMouse

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Component.onCompleted: {
        if (iconName === "") {
            console.warn("[ButtonIcon] Required property 'iconName' is empty");
        }
    }
}
