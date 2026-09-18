import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.Core.Services
import Quickshell.Wayland
import qs.Shared.Background
import qs.Core
import QtQuick.Effects

PanelWindow {
    id: root
    color: "transparent"

    visible: false

    implicitWidth: (contentLoader.item ? contentLoader.item.implicitWidth : 300) + 24
    implicitHeight: (contentLoader.item ? contentLoader.item.implicitHeight : 200) + 24

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    GlobalShortcut {
        name: "audio_panel"
        description: "Toggle Audio Panel"
        onPressed: root.visible = !root.visible
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible)
                Qt.callLater(() => root.visible = false);
        }
    }

    // Escape cierra. M/mute se maneja en el foco:
    // bigButton con Enter/Espacio, sliders con M.
    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => contentLoader.item?.focusDefault?.());
    }
    PopupBackground {
        id: bg

        anchors.fill: parent
    }

    MultiEffect {
        source: bg
        anchors.fill: bg
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowBlur: 0.85
        shadowVerticalOffset: 6
        shadowHorizontalOffset: 0
        blurMax: 32
        shadowOpacity: 0.18
        z: -1
    }

    // Síncrono a propósito: el contenido mide según datos vivos (número
    // de dispositivos, volúmenes) y en async la ventana abría en tamaño
    // de fallback y saltaba al real, desplazando los sliders a la vista.
    // Es un popup pequeño: instanciar en el mismo frame no se nota y al
    // cerrar se sigue destruyendo (ahorro intacto).
    Loader {
        id: contentLoader

        anchors {
            fill: parent
            margins: 12
        }
        active: root.visible
        sourceComponent: volumeComp
        onLoaded: {
            if (root.visible)
                Qt.callLater(() => contentLoader.item?.focusDefault?.());
        }
    }

    Component {
        id: volumeComp

        VolumePopupContent {
            anchors.fill: parent
        }
    }
}
