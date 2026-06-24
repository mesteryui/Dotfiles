// MprisSubwindow — Wrapper
// Gestiona estado de posición, timers, focus y ensambla Background + Content.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Core.Services as Services
import qs.Shared.Background

PopupWindow {
    id: root

    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: 350
    implicitHeight: mprisContent.implicitHeight

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

    Timer {
        id: positionTimer
        interval: 250
        repeat: true
        running: root.visible && Services.MprisService.isPlaying
        onTriggered: {
            if (!mprisContent.sliderDragging && Services.MprisService.currentMprisPlayer)
                root.currentPosition = Services.MprisService.currentMprisPlayer.position
        }
    }

    Timer {
        id: seekConfirmTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (Services.MprisService.currentMprisPlayer && !mprisContent.sliderDragging)
                root.currentPosition = Services.MprisService.currentMprisPlayer.position
        }
    }

    // ── Sincronización con el player ──────────────────────────
    Connections {
        target: Services.MprisService.currentMprisPlayer
        enabled: Services.MprisService.currentMprisPlayer !== null

        function onPositionChanged() {
            if (!mprisContent.sliderDragging)
                root.currentPosition = Services.MprisService.currentMprisPlayer.position
        }

        function onPlaybackStateChanged() {
            Qt.callLater(() => {
                if (Services.MprisService.currentMprisPlayer && !mprisContent.sliderDragging)
                    root.currentPosition = Services.MprisService.currentMprisPlayer.position
            })
        }
    }

    Connections {
        target: Services.MprisService
        function onCurrentMprisPlayerChanged() {
            root.currentPosition = Services.MprisService.currentMprisPlayer?.position ?? 0
        }
    }

    onVisibleChanged: {
        if (visible)
            root.currentPosition = Services.MprisService.currentMprisPlayer?.position ?? 0
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

        onSeekRequested: (pos) => {
            root.currentPosition = pos
            Services.MprisService.seekTo(pos)
            seekConfirmTimer.restart()
        }
    }
}
