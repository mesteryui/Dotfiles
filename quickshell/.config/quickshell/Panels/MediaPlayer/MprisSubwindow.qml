// MprisSubwindow — Wrapper
// Gestiona estado de posición, timers, focus y ensambla Background + Content.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Core.Services as Services
import qs.Shared.Background
import Quickshell.Services.Mpris

PopupWindow {
    id: root

    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: 350
    implicitHeight: mprisContent.implicitHeight
    

    readonly property var player: Services.MprisService.activePlayer

    // Portada: cadena declarativa, sin onXChanged con efectos secundarios.
    // Si no hay player o no hay arte, queda en "" (sin imagen), en vez de
    // resolver una URL basura contra el directorio del propio .qml.
    readonly property string artURL: player?.trackArtUrl ?? ""
    readonly property string finalArt: artURL.length > 0 ? Qt.resolvedUrl(artURL) : ""
    // ── Estado de posición ────────────────────────────────────
    property real currentPosition: 0


    // ── Focus ─────────────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible) Qt.callLater(() => root.visible = false)
        }
    }

    // ── Timers de posición ────────────────────────────────────
    // Referencia mprisContent.sliderDragging en vez de progressSlider.pressed
    // para no acoplar el Wrapper a un id interno del Content.

    // ── Timers de posición ────────────────────────────────────
    Timer {
        id: positionTimer
        interval: 250
        repeat: true
        running: root.visible && Services.MprisService.isPlaying
        onTriggered: {
            // ✅ CORREGIDO: Usar activePlayer
            if (!mprisContent.sliderDragging && Services.MprisService.activePlayer)
                root.currentPosition = Services.MprisService.activePlayer.position
        }
    }

    Timer {
        id: seekConfirmTimer
        interval: 350
        repeat: false
        onTriggered: {
            // ✅ CORREGIDO: Usar activePlayer
            if (Services.MprisService.activePlayer && !mprisContent.sliderDragging)
                root.currentPosition = Services.MprisService.activePlayer.position
        }
    }

    onVisibleChanged: {
        if (visible)
            // ✅ CORREGIDO: Usar activePlayer
            root.currentPosition = Services.MprisService.activePlayer?.position ?? 0
    }

    // ── Background ────────────────────────────────────────────
    PopupBackground {
        anchors.fill: parent
    }

   

    // ── Content ───────────────────────────────────────────────
    MprisContent {
        id: mprisContent
        anchors.fill: parent
        currentPosition: root.currentPosition
        onSeekRequested: (newPosition) => {
            if (Services.MprisService.activePlayer) {
                Services.MprisService.activePlayer.position = newPosition // Cambia la canción
                root.currentPosition = newPosition // Actualiza la UI instantáneamente
                seekConfirmTimer.start() // Evita que el positionTimer machaque el valor antes de que DBus responda
            }
        }
        artURL: root.finalArt
    }
}
