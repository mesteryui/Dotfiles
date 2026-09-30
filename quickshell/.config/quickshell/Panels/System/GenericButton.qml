import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import Quickshell.Io
import M3Shapes

// Botón de potencia: reposo siempre en Circle; al resaltar morfea a
// su forma-identidad (p. ej. apagar = Circle, salir = Arrow).
// Cuadrado garantizado: MaterialShape normaliza a
// min(width, height) y un botón más ancho que alto dejaría el texto fuera.
MaterialShape {
    id: root

    required property string buttonIcon
    required property string buttonText
    required property string command

    property color accentColor: Appearance.md3.primary

    // Forma-identidad del botón (se muestra al resaltar).
    property int buttonShape: MaterialShape.Circle

    readonly property bool highlighted: activeFocus || btnMouse.containsMouse

    focus: true

    shape: btnMouse.pressed ? MaterialShape.Cookie4Sided : (root.highlighted ? root.buttonShape : MaterialShape.Circle)
    animationDuration: 300
    color: highlighted ? accentColor : Appearance.md3.surface_container
    strokeWidth: highlighted ? 2 : 1
    strokeColor: highlighted ? Qt.alpha(accentColor, 0.7) : Appearance.md3.outline_variant

    // Lado dinámico: mínimo 120 o lo que pida el contenido + margen.
    // Mismo valor en ambos ejes para mantener el cuadrado.
    property real side: Math.max(120, contentColumn.implicitWidth + 36, contentColumn.implicitHeight + 36)
    implicitWidth: side
    implicitHeight: side

    Process {
        id: runCommand

        command: ["bash", "-c", root.command]
    }

    Column {
        id: contentColumn

        anchors.centerIn: parent
        spacing: 10

        // Exponemos el tamaño para el cálculo del lado del botón
        readonly property real implicitWidth: Math.max(iconItem.width, buttonTextItem.implicitWidth)

        readonly property real implicitHeight: iconItem.height + spacing + buttonTextItem.implicitHeight

        MaterialIcon {
            id: iconItem

            anchors.horizontalCenter: parent.horizontalCenter
            icon: root.buttonIcon
            size: 32
            // Sobre fondo accent sólido: on_primary; en reposo: on_surface.
            color: root.highlighted ? Appearance.md3.on_primary : Appearance.md3.on_surface
        }

        StyledText {
            id: buttonTextItem

            anchors.horizontalCenter: parent.horizontalCenter
            text: root.buttonText
            font.family: Services.ConfigService.configs.appearance.fontSans
            color: root.highlighted ? Appearance.md3.on_primary : Appearance.md3.on_surface
            font.pixelSize: 12
            font.weight: root.highlighted ? Font.Bold : Font.Normal

            Behavior on color { ColorAnimation { duration: Appearance.motion.short3 } }
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
