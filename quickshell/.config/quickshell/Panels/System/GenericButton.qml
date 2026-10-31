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

    // Acción shell clásica (bash -c). Puede quedar vacía si se usa
    // `hyprlandIpcCommand`.
    property string command: ""

    // Si se fija, el click envía la orden por el socket IPC de Hyprland
    // (HyprlandIpc, sin fork) en vez de ejecutar `command` en bash.
    // P.ej. "dispatch hl.dsp.exit()" o "reload".
    property string hyprlandIpcCommand: ""

    property color accentColor: Appearance.md3.primary

    // Forma-identidad del botón (se muestra al resaltar).
    property int buttonShape: MaterialShape.Circle

    readonly property bool highlighted: activeFocus || btnMouse.containsMouse

    focus: true

    shape: btnMouse.pressed ? MaterialShape.Cookie4Sided : (root.highlighted ? root.buttonShape :
                                                                               MaterialShape.Circle)

    animationDuration: Appearance.motion.slow
    color: highlighted ? accentColor : Appearance.md3.surface_container
    strokeWidth: highlighted ? Appearance.border.focusWidth : Appearance.border.width
    strokeColor: highlighted ? Qt.alpha(root.accentColor, 0.7) : Appearance.border.subtleOn(
                                   Appearance.md3.surface_container)

    // Lado dinámico: mínimo 120 o lo que pida el contenido + margen.
    // Mismo valor en ambos ejes para mantener el cuadrado.
    property real side: Math.max(120, contentColumn.implicitWidth + 36, contentColumn.implicitHeight + 36)
    implicitWidth: side
    implicitHeight: side

    Process {
        id: runCommand

        command: ["bash", "-c", root.command]
    }

    function activate() {
        if (root.hyprlandIpcCommand !== "")
            Services.HyprlandIpc.send(root.hyprlandIpcCommand);
        else if (root.command !== "")
            runCommand.running = true;
        else
            console.warn("[GenericButton] sin acción: ni command ni hyprlandIpcCommand.");
    }

    Column {
        id: contentColumn

        anchors.centerIn: parent
        spacing: Appearance.spacing.medium

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
            font.pixelSize: Appearance.typeScale.labelMedium
            font.weight: root.highlighted ? Font.Bold : Font.Normal

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.motion.fast
                }
            }
        }
    }

    MouseArea {
        id: btnMouse

        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.forceActiveFocus()
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }

    Keys.onReturnPressed: root.activate()

    Keys.onEnterPressed: root.activate()

    Keys.onSpacePressed: root.activate()
}
