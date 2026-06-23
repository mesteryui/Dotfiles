import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Core
import qs.Core.Services as Services
import qs.Primitives

Rectangle {
    id: root
    required property string buttonIcon
    required property string buttonText
    required property string command
    
    property color accentColor: Colors.md3.primary
    
    readonly property bool highlighted: activeFocus || btnMouse.containsMouse
    focus: true

    // Tamaño dinámico: mínimo 100x100 o lo que pida el contenido + margen
    implicitWidth: Math.max(100, contentColumn.implicitWidth + 32)
    implicitHeight: Math.max(100, contentColumn.implicitHeight + 32)
    
    radius: 20
    color: highlighted
        ? accentColor
        : Colors.md3.surface_container

    Behavior on color { ColorAnimation { duration: 150 } }

    border.width: highlighted ? 2 : 1
    border.color: highlighted
        ? Qt.alpha(accentColor, 0.7)
        : Colors.md3.outline_variant

    Behavior on border.color { ColorAnimation { duration: 150 } }

    scale: btnMouse.pressed ? 0.93 : (highlighted ? 1.06 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
    }

    // Eliminado el MultiEffect para quitar sombras y efectos planos

    Process {
        id: runCommand
        command: ["bash", "-c", root.command]
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 10
        
        // Exponemos el tamaño para el cálculo de implicitWidth/Height del root
        readonly property real implicitWidth: Math.max(iconItem.width, buttonTextItem.implicitWidth)
        readonly property real implicitHeight: iconItem.height + spacing + buttonTextItem.implicitHeight

        MaterialIcon {
            id: iconItem
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.buttonIcon
            size: 32
            // Color plano basado en si está resaltado o no
            color: highlighted ? Colors.md3.on_primary : Colors.md3.on_surface
        }

        StyledText {
            id: buttonTextItem
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.buttonText
            font.family: Services.ConfigService.configs.appearence.fontSans
            color: highlighted ? Colors.md3.on_primary : Colors.md3.on_surface
            font.pixelSize: 12
            font.weight: highlighted ? Font.Bold : Font.Normal
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: btnMouse
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.forceActiveFocus()
        cursorShape: Qt.PointingHandCursor
        onClicked: runCommand.running = true
    }

    Keys.onReturnPressed: runCommand.running = true
    Keys.onEnterPressed: runCommand.running = true
    Keys.onSpacePressed: runCommand.running = true
}
