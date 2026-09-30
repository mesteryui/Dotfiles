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

    // Posición optimista post-seek: el player aplica el seek de forma
    // asíncrona, así que durante ~1s tras pedirlo la posición que manda es
    // la pedida (evita el "salto atrás"). Se libera antes si lo reportado
    // alcanza lo pedido (tolerancia 1s), o al expirar el periodo.
    property real seekTarget: -1
    property double seekTargetUntil: 0

    // Posición vía MprisService.position (timer único centralizado):
    // este popup se apunta al hacerse visible y se desapunta al
    // ocultarse/destruirse.
    Connections {
        target: MprisService
        function onPositionChanged() {
            if (mprisContent.sliderDragging)
                return;
            if (root.seekTarget >= 0) {
                if (Date.now() < root.seekTargetUntil) {
                    // El player ya llegó (o pasó): adoptar y liberar.
                    if (MprisService.position >= root.seekTarget - 1.0) {
                        root.seekTarget = -1;
                        root.currentPosition = MprisService.position;
                    }
                    // Si no, mantener la optimista: ignorar el valor rancio.
                    return;
                }
                root.seekTarget = -1;
            }
            root.currentPosition = MprisService.position;
        }

        // Cambio de pista: el seek pendiente (si lo había) ya no vale y la
        // posición optimista heredada mentiría contra la nueva duración.
        function onTrackChanged() {
            root.seekTarget = -1;
            root.currentPosition = 0;
        }
    }

    onVisibleChanged: {
        MprisService.positionClients += visible ? 1 : -1;
        // Al abrir/cerrar se invalida cualquier seek pendiente.
        root.seekTarget = -1;
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
            // Fijar la optimista de inmediato: la barra y los tiempos ya
            // muestran el destino sin esperar al D-Bus (ver grace arriba).
            root.currentPosition = newPosition;
            root.seekTarget = newPosition;
            root.seekTargetUntil = Date.now() + 1000;
        }
        artURL: root.finalArt
    }
}
