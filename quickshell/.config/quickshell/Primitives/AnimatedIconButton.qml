import qs.Core
import qs.Primitives
import QtQuick

Item {
    id: root

    property string icon: ""
    property int iconSize: 24
    property bool isActive: false

    property color baseColor: "transparent"
    property color accentColor: Appearance.md3.primary

    // Icon colors based on state
    property color iconColor: Appearance.md3.on_surface
    property color activeIconColor: Appearance.md3.on_primary
    property color disabledIconColor: Qt.alpha(Appearance.md3.on_surface, Appearance.state.disabled)

    signal clicked

    implicitWidth: 44
    implicitHeight: 44

    scale: mouseArea.pressed ? 0.92 : (mouseArea.containsMouse ? 1.06 : 1.0)

    Behavior on scale {
        SpringAnimation {
            spring: Appearance.motion.springSnappy.spring
            damping: Appearance.motion.springSnappy.damping
            mass: Appearance.motion.springSnappy.mass
            epsilon: 0.005
        }
    }

    Rectangle {
        id: bgRect

        anchors.fill: parent
        radius: width / 2
        color: root.isActive ? root.accentColor : root.baseColor

        Behavior on color {
            ColorAnimation {
                duration: Appearance.motion.fast
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.isActive ? Appearance.md3.on_primary : Appearance.md3.on_surface
            opacity: mouseArea.pressed ? Appearance.state.pressed : (mouseArea.containsMouse
                                                                     ? Appearance.state.hovered : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.motion.veryFast
                }
            }
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        color: root.enabled ? (root.isActive ? root.activeIconColor : root.iconColor) : root.disabledIconColor

        Behavior on color {
            ColorAnimation {
                duration: Appearance.motion.fast
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
