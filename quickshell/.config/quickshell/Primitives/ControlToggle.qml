// ControlToggle — Pill/Tile estilo Material 3 Expressive Quick Settings.
// Soporta vista compacta o vista con estado de 2 líneas (stateText).
import qs.Core
import QtQuick
import QtQuick.Layouts
import M3Shapes

Rectangle {
    id: root

    property string label:     ""
    property string stateText: ""
    property string iconName:  ""
    property bool   active:    false
    property bool   enable:    true
    // Patrón focus-visible (ver ControlSlider): el anillo de foco solo se
    // muestra en modo teclado. Por defecto true para no cambiar usos existentes.
    property bool   keyboardMode: true

    signal toggled()
    signal mouseUsed

    implicitWidth:  140
    implicitHeight: root.stateText !== "" ? 72 : 48

    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.checkable: true
    Accessible.checked: root.active
    Accessible.name: root.label
    Accessible.description: root.stateText

    Keys.onReturnPressed: { if (root.enable) root.toggled(); }
    Keys.onEnterPressed: { if (root.enable) root.toggled(); }
    Keys.onSpacePressed: { if (root.enable) root.toggled(); }

    radius: Appearance.shape.large
    color: root.active
        ? Appearance.md3.primary_container
        : Appearance.md3.surface_container_high
    opacity: root.enable ? 1.0 : Appearance.state.disabled
    border.width: (root.activeFocus && root.keyboardMode) ? 2 : 0
    border.color: Appearance.md3.primary

    scale: hoverArea.pressed ? 0.96 : (hoverArea.containsMouse ? 1.02 : 1.0)

    Behavior on color { ColorAnimation { duration: Appearance.motion.short3 } }
    Behavior on opacity { OpacityAnimator { duration: Appearance.motion.short3 } }
    Behavior on scale { ScaleAnimator { duration: 140; easing.type: Easing.OutCubic } }

    // Capa de estado M3 Expressive (Hover & Press overlay + foco de teclado)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.active ? Appearance.md3.on_primary_container : Appearance.md3.on_surface
        opacity: hoverArea.pressed ? Appearance.state.pressed : (hoverArea.containsMouse || (root.activeFocus && root.keyboardMode) ? Appearance.state.hovered : 0.0)

        Behavior on opacity { NumberAnimation { duration: Appearance.motion.short2 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.stateText !== "" ? 12 : 8
        spacing: 10

        // Contenedor del icono estilo badge M3 (círculo expresivo).
        MaterialShape {
            id: iconBadge
            Layout.preferredWidth: root.stateText !== "" ? 36 : 32
            Layout.preferredHeight: root.stateText !== "" ? 36 : 32

            shape: MaterialShape.Circle
            color: root.active ? Appearance.md3.primary : Appearance.md3.surface_container_highest
            animationDuration: 150

            Behavior on color { ColorAnimation { duration: Appearance.motion.short3 } }

            MaterialIcon {
                anchors.centerIn: parent
                icon: root.iconName
                size: root.stateText !== "" ? Appearance.font.pixelSize.large : Appearance.typeScale.bodyLarge
                color: root.active ? Appearance.md3.on_primary : Appearance.md3.on_surface_variant

                Behavior on color { ColorAnimation { duration: Appearance.motion.short3 } }
            }
        }

        // Textos (Título + Subtítulo opcional)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Layout.alignment: Qt.AlignVCenter

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Appearance.typeScale.titleSmall
                font.weight: root.active ? Font.Medium : Font.Normal
                color: root.active ? Appearance.md3.on_primary_container : Appearance.md3.on_surface
                elide: Text.ElideRight

                Behavior on color { ColorAnimation { duration: Appearance.motion.short3 } }
            }

            StyledText {
                id: stateLabel

                visible: root.stateText !== ""
                Layout.fillWidth: true
                text: root.stateText
                font.pixelSize: Appearance.typeScale.labelSmall
                color: root.active ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                elide: Text.ElideRight

                Behavior on color { ColorAnimation { duration: Appearance.motion.short3 } }
            }
        }
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enable
        cursorShape: Qt.PointingHandCursor
        onEntered: root.mouseUsed()
        onPressed: {
            root.forceActiveFocus();
            root.mouseUsed();
        }
        onClicked: root.toggled()
    }
}

