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

    implicitWidth: popupContent.implicitWidth + 24
    implicitHeight: popupContent.implicitHeight + 24

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

    Shortcut {
        sequence: "Right"
        onActivated: AudioService.setVolume(AudioService.volume + 0.05)
    }
    Shortcut {
        sequence: "Left"
        onActivated: AudioService.setVolume(AudioService.volume - 0.05)
    }

    Shortcut {
        sequence: "Shift + Left"
        onActivated: AudioService.setMicVolume(AudioService.micVolume - 0.05)
    }
    Shortcut {
        sequence: "Shift + Right"
        onActivated: AudioService.setMicVolume(AudioService.micVolume + 0.05)
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

    VolumePopupContent {
        id: popupContent
        anchors {
            fill: parent
            margins: 12
        }
    }
}
