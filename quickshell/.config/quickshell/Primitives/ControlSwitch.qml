// ControlSwitch — Switch Material 3 a spec.
// Track 52x32 (off: surface-container-highest + outline 2px; on: primary),
// thumb 16 off → 24 on con icono check, morph 150ms.
// `interactive: false` lo deja como indicador visual (p. ej. dentro de
// ControlToggle, que ya gestiona toggle + foco por sí mismo).
import qs.Core
import QtQuick
import M3Shapes

Item {
    id: root

    property bool checked: false
    property bool interactive: true
    property bool enable: true
    property bool showIcon: true

    signal toggled()

    implicitWidth: 52
    implicitHeight: 32

    activeFocusOnTab: root.interactive && root.enable
    Accessible.role: Accessible.CheckBox
    Accessible.checked: root.checked
    Accessible.name: "switch"

    Keys.onSpacePressed: { if (root.interactive && root.enable) root.toggled(); }
    Keys.onReturnPressed: { if (root.interactive && root.enable) root.toggled(); }
    Keys.onEnterPressed: { if (root.interactive && root.enable) root.toggled(); }

    opacity: root.enable ? 1.0 : Appearance.state.disabled

    Behavior on opacity { NumberAnimation { duration: Appearance.motion.short3 } }

    // Track
    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Appearance.md3.primary : Appearance.md3.surface_container_highest
        border.width: root.checked ? 0 : 2
        border.color: Appearance.md3.outline

        Behavior on color { ColorAnimation { duration: Appearance.motion.short3 } }
        Behavior on border.width { NumberAnimation { duration: Appearance.motion.short3 } }
    }

    // Anillo de foco visible (solo interactivo + teclado).
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Appearance.md3.primary
        visible: root.interactive && root.activeFocus
    }

    // Thumb M3 (16 off → 24 on, icono check en on) como MaterialShape:
    // círculo expresivo con la misma métrica que el rectángulo anterior.
    MaterialShape {
        id: thumb

        width: root.checked ? 24 : 16
        height: width
        shape: MaterialShape.Circle
        color: root.checked ? Appearance.md3.on_primary : Appearance.md3.outline
        animationDuration: 150
        x: root.checked ? (52 - 8 - 24) : 8
        y: (32 - height) / 2

        Behavior on x { NumberAnimation { duration: Appearance.motion.short3; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Appearance.motion.short3; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Appearance.motion.short3; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Appearance.motion.short3 } }

        MaterialIcon {
            anchors.centerIn: parent
            icon: "check"
            size: 16
            color: Appearance.md3.on_primary_container
            visible: root.showIcon && root.checked
        }
    }

    // State layer del thumb al hover (solo interactivo).
    Rectangle {
        width: 40
        height: 40
        radius: width / 2
        color: root.checked ? Appearance.md3.primary : Appearance.md3.on_surface
        opacity: root.interactive && root.enable ? (switchMouse.pressed ? Appearance.state.pressed : (switchMouse.containsMouse ? Appearance.state.hovered : 0.0)) : 0.0
        x: thumb.x + thumb.width / 2 - width / 2
        y: thumb.y + thumb.height / 2 - height / 2

        Behavior on opacity { NumberAnimation { duration: Appearance.motion.short2 } }
    }

    MouseArea {
        id: switchMouse

        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive && root.enable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
