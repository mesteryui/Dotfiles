import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import "../../Core"
import "../../Core/Services" as Services
import "../../Components"
import "."
Rectangle {
    id: root
    required property string buttonIcon
    required property string buttonText
    required property string command
    
    // Opcional: color de acento por botón (rojo para apagar, etc.)
    property color accentColor: Colors.primary
    
    readonly property bool highlighted: activeFocus || btnMouse.containsMouse
    focus: true

    implicitWidth: 100
    implicitHeight: 100
    radius: 20
    color: highlighted
        ? Qt.alpha(accentColor, 0.18)
        : Qt.alpha(Colors.surface_container, 0.9)

    Behavior on color { ColorAnimation { duration: 150 } }

    // Borde que se ilumina en hover
    border.width: highlighted ? 2 : 1
    border.color: highlighted
        ? Qt.alpha(accentColor, 0.7)
        : Colors.outline_variant

    Behavior on border.color { ColorAnimation { duration: 150 } }

    // Escala en hover/press
    scale: btnMouse.pressed ? 0.93 : (highlighted ? 1.06 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
    }

    // Glow al hacer hover
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: highlighted
        shadowColor: Qt.alpha(root.accentColor, 0.5)
        shadowBlur: 0.9
        shadowVerticalOffset: 0
        shadowHorizontalOffset: 0
        blurMax: 24
        shadowOpacity: highlighted ? 0.8 : 0
        Behavior on shadowOpacity { NumberAnimation { duration: 200 } }
    }
    Process {
        id: runCommand
        command: ["bash", "-c", root.command]
    }
    Column {
        anchors.centerIn: parent
        spacing: 10

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.buttonIcon
            size: 32
            color: highlighted ? root.accentColor : Colors.on_surface

            // Tinte del icono en hover
            layer.enabled: highlighted
            layer.effect: MultiEffect {
                colorization: highlighted ? 1.0 : 0.0
                colorizationColor: root.accentColor
            }
        }

            Text {
                id: buttonTextItem
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.buttonText
                font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                color: highlighted ? root.accentColor : Colors.on_surface
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