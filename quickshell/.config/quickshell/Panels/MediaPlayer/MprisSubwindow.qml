// MprisSubwindow — Wrapper
// Gestiona estado de posición, timers, focus y ensambla Background + Content.

import qs.Core.Services
import "../../Core/Log.js" as Log
import qs.Shared.Background
import qs.Primitives
import QtQuick

BarPopupWindow {
    id: root

    implicitWidth: 360
    implicitHeight: mprisContent.implicitHeight

    readonly property var player: MprisService.activePlayer

    // Portada: cadena declarativa, sin onXChanged con efectos secundarios.
    // Si no hay player o no hay arte, queda en "" (sin imagen), en vez de
    // resolver una URL basura contra el directorio del propio .qml.
    // Las data: URLs (navegadores) se descartan aquí también: suelen venir
    // truncadas y spamean el log desde los decodificadores Qt (ver
    // MprisService._cleanArtUrl).
    readonly property string artURL: {
        const u = String(player?.trackArtUrl ?? "");
        return u.startsWith("data:") ? "" : u;
    }

    readonly property string finalArt: artURL.length > 0 ? Qt.resolvedUrl(artURL) : ""

    property real currentPosition: 0

    // Posición vía MprisService.position (timer único centralizado):
    // este popup se apunta al hacerse visible y se desapunta al
    // ocultarse/destruirse. La confirmación post-seek sigue siendo un
    // one-shot por gesto (barato y dirigido).
    Connections {
        target: MprisService
        function onPositionChanged() {
            if (!mprisContent.sliderDragging)
                root.currentPosition = MprisService.position;
        }
    }

    Timer {
        id: seekConfirmTimer

        interval: 200
        repeat: false
        onTriggered: {
            if (!mprisContent.sliderDragging) {
                const p = MprisService.activePlayer;
                if (!p)
                    return;
                try {
                    root.currentPosition = p.position;
                } catch (e) {
                    Log.warn("[Mpris] seek confirm read failed:", e);
                }
            }
        }
    }

    onVisibleChanged: {
        MprisService.positionClients += visible ? 1 : -1;
        if (visible) {
            const p = MprisService.activePlayer;
            if (!p) {
                root.currentPosition = 0;
            } else {
                try {
                    root.currentPosition = p.position;
                } catch (e) {
                    root.currentPosition = 0;
                    Log.warn("[Mpris] visible init read failed:", e);
                }
            }
        }
    }

    Component.onDestruction: {
        if (root.visible)
            MprisService.positionClients -= 1;
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
            const p = MprisService.activePlayer;
            if (!p)
                return;
            if (!(p.canSeek || p.canControl)) {
                Log.warn("[Mpris] seek ignored: player not controllable");
                return;
            }
            try {
                p.position = newPosition;
            } catch (e) {
                Log.warn("[Mpris] seek failed:", e);
                // opcional: MprisService.setActivePlayer(null);
            }
            root.currentPosition = newPosition;
            seekConfirmTimer.start();
        }
        artURL: root.finalArt
    }
}
