import qs.Core
import QtQuick
import M3Shapes

Item {
    id: root

    required property string icon

    property int iconSize: 16

    property color iconColor: Appearance.md3.on_surface

    property int padding: Appearance.spacing.extraSmall

    signal clicked

    // Dimensiones implícitas que incluyen el padding para la zona interactiva
    implicitWidth: iconSize + (padding * 2)
    implicitHeight: iconSize + (padding * 2)

    opacity: enabled ? 1.0 : Appearance.state.disabled

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.motion.fast
        }
    }

    // State layer M3 (icon-button estándar): velo circular al hover/press.
    MaterialShape {
        anchors.centerIn: parent
        width: Math.max(parent.width, parent.height)
        height: width
        shape: MaterialShape.Circle
        color: Appearance.md3.on_surface
        opacity: iconMouse.pressed ? Appearance.state.pressed : (iconMouse.containsMouse
                                                                 ? Appearance.state.hovered : 0.0)

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.motion.veryFast
            }
        }
    }

    MaterialIcon {
        id: iconItem

        anchors.centerIn: parent
        icon: root.icon
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
        if (icon === "") {
            console.warn("[ButtonIcon] Required property 'icon' is empty");
        }
    }
}
