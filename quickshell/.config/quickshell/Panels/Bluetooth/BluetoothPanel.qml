// --- BluetoothPanel: popup de la barra con dispositivos y batería ---
import qs.Core.Services
import qs.Core
import qs.Shared.Background
import qs.Primitives
import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland

BarPopupWindow {
    id: root

    implicitWidth: popupContent.implicitWidth + 24
    implicitHeight: popupContent.implicitHeight + 24

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

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    PopupBackground {
        id: bg

        anchors.fill: parent
    }

    BluetoothPopupContent {
        id: popupContent
        anchors {
            fill: parent
            margins: 12
        }
    }
}
