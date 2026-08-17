// MprisSubwindow — Wrapper
// Gestiona estado de posición, timers, focus y ensambla Background + Content.

import QtQuick
import qs.Core.Services as Services
import qs.Shared.Background
import qs.Primitives

BarPopupWindow {
    id: root

    implicitWidth: 350
    implicitHeight: mprisContent.implicitHeight

    readonly property var player: Services.MprisService.activePlayer

    // Portada: cadena declarativa, sin onXChanged con efectos secundarios.
    // Si no hay player o no hay arte, queda en "" (sin imagen), en vez de
    // resolver una URL basura contra el directorio del propio .qml.
    readonly property string artURL: player?.trackArtUrl ?? ""
    readonly property string finalArt: artURL.length > 0 ? Qt.resolvedUrl(artURL) : ""

    property real currentPosition: 0


    Timer {
        id: positionTimer
        interval: 100
        repeat: true
        running: root.visible && Services.MprisService.isPlaying
        onTriggered: {
            if (!mprisContent.sliderDragging) {
                const p = Services.MprisService.activePlayer;
                if (!p)
                    return;
                // Solo leer si parece controlable; atrapar excepciones por si el servicio cae entre medias
                if (p.canSeek || p.canControl || p.position !== undefined) {
                    try {
                        root.currentPosition = p.position;
                    } catch (e) {
                        console.warn("[Mpris] position read failed:", e);
                    }
                }
            }
        }
    }

    Timer {
        id: seekConfirmTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (!mprisContent.sliderDragging) {
                const p = Services.MprisService.activePlayer;
                if (!p)
                    return;
                try {
                    root.currentPosition = p.position;
                } catch (e) {
                    console.warn("[Mpris] seek confirm read failed:", e);
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            const p = Services.MprisService.activePlayer;
            if (!p) {
                root.currentPosition = 0;
            } else {
                try {
                    root.currentPosition = p.position;
                } catch (e) {
                    root.currentPosition = 0;
                    console.warn("[Mpris] visible init read failed:", e);
                }
            }
        }
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
        onSeekRequested: newPosition => {
            const p = Services.MprisService.activePlayer;
            if (!p)
                return;
            if (!(p.canSeek || p.canControl)) {
                console.warn("[Mpris] seek ignored: player not controllable");
                return;
            }
            try {
                p.position = newPosition;
            } catch (e) {
                console.warn("[Mpris] seek failed:", e);
                // opcional: Services.MprisService.setActivePlayer(null);
            }
            root.currentPosition = newPosition;
            seekConfirmTimer.start();
        }
        artURL: root.finalArt
    }
}
