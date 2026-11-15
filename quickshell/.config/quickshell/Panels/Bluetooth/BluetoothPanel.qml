// --- BluetoothPanel: popup de la barra con dispositivos y batería ---
import qs.Core
import qs.Shared.Background
import qs.Primitives
import QtQuick
import QtQuick.Effects

BarPopupWindow {
    id: root

    implicitWidth: popupContent.implicitWidth + 24
    implicitHeight: popupContent.implicitHeight + 24

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    PopupBackground {
        id: bg

        anchors.fill: parent
        surfaceRadius: Appearance.shape.card
        baseColor: Appearance.md3.surface
        showBorder: true
    }

    // Sombra: source se asigna en onCompleted para evitar warning
    // "ShaderEffect: 'source' does not have a matching property" del primer frame.

    // El contenido llena bg (con clip y radius), no el padre directo, y no
    // renderiza bordes propios.
    BluetoothPopupContent {
        id: popupContent
        anchors {
            fill: bg
            margins: Appearance.spacing.medium
        }
    }
}
