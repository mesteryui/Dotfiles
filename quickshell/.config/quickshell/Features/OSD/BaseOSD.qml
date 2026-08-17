import Quickshell
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    property int implicitHeight: 20
    property int implicitWidth: 20
    default property alias content: container.data

    // Estado "lógico" de visibilidad, desacoplado del visible real de la ventana.
    // window.visible se mantiene true mientras dura la animación de salida,
    // para que el fade-out se pueda ver antes de desmapear la superficie Wayland.
    property bool shown: false

    Timer {
        id: osdTimer
        repeat: false
        interval: 3000
        running: root.shown
        onTriggered: root.shown = false
    }

    function show(): void {
        root.shown = true
        osdTimer.restart()   // reinicia el conteo aunque el OSD ya estuviera visible
    }

    PanelWindow {
        id: window

        // Sigue mapeada mientras se muestra, o mientras el fade-out está animando
        visible: root.shown || fadeAnim.running

        screen: root.focusedScreen   // binding declarativo puro, no necesita Connections

        WlrLayershell.namespace: "quickshell:osd"
        WlrLayershell.layer: WlrLayer.Overlay
        implicitHeight: root.implicitHeight
        implicitWidth: root.implicitWidth
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"

        anchors.top: true
        margins.top: 55

        Item {
            id: container
            anchors.fill: parent
            opacity: root.shown ? 1.0 : 0.0

            Behavior on opacity {
                OpacityAnimator {
                    id: fadeAnim
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}