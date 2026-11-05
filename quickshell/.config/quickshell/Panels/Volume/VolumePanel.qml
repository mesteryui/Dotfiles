// --- AudioPopupWindow ---
// Wrapper: PopupWindow de la barra para el control de audio (salida + micrófono).
import qs.Core
import qs.Shared.Background
import qs.Primitives
import QtQuick
import QtQuick.Effects

BarPopupWindow {
    id: root

    implicitWidth: popupContent.implicitWidth + 24
    implicitHeight: popupContent.implicitHeight + 24


    // Escape cierra. M/mute se maneja en el foco:
    // bigButton con Enter/Espacio, sliders con M.
    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => popupContent.focusDefault());
    }

    PopupBackground {
        id: bg

        anchors.fill: parent
        surfaceRadius: Appearance.shape.card
        baseColor: Appearance.md3.surface
        showBorder: true
    }

    // El contenido llena bg (con clip y radius), no el padre directo, y no
    // renderiza bordes propios.
    VolumePopupContent {
        id: popupContent
        anchors {
            fill: bg
            margins: Appearance.spacing.medium
        }
    }
}
