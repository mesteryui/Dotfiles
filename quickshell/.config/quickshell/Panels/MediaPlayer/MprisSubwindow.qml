// MprisSubwindow — Wrapper
// Gestiona estado de posición, timers, focus y ensambla Background + Content.

import qs.Core
import qs.Core.Services
import qs.Shared.Background
import qs.Primitives
import QtQuick
import Quickshell.Io

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

    // Las carátulas file:// de navegadores (p. ej. Zen/Firefox
    // ~/.config/zen/firefox-mpris/<pid>_<n>.png) son racy: MPRIS anuncia
    // la URL antes de que el archivo exista (o con el PID de una sesión
    // anterior ya borrada) y QQuickImage spamea
    // "Cannot open: file:///...png". Se valida con FileView silencioso
    // (printErrors:false): sin archivo no se publica URL y el Image ni
    // lo intenta (enseña placeholder). watchChanges cubre el caso en que
    // el archivo aparece justo después del anuncio MPRIS.
    // file:///home/x → /home/x (slice(7) quita "file://").
    // Se decodifica %XX (espacios, etc.) y se tolera file://localhost/….
    readonly property string artLocalPath: {
        if (!root.artURL.startsWith("file://"))
            return "";
        let p = root.artURL.slice(7);
        if (p.startsWith("localhost"))
            p = p.slice(9);
        try {
            return decodeURIComponent(p);
        } catch (e) {
            return p;
        }
    }

    FileView {
        id: artProbe

        path: root.artLocalPath
        blockLoading: root.artLocalPath === ""
        printErrors: false
        watchChanges: true
    }

    readonly property string finalArt: {
        if (root.artURL.length === 0)
            return "";
        // Local: solo si el fichero existe (evita el WARN de QQuickImage).
        if (root.artLocalPath !== "")
            return artProbe.loaded ? Qt.resolvedUrl(root.artURL) : "";
        return Qt.resolvedUrl(root.artURL);
    }

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
                    console.warn("[Mpris] visible init read failed:", e);
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
        id: bg

        anchors.fill: parent
        surfaceRadius: Appearance.shape.card
        baseColor: Appearance.md3.surface
        showBorder: true
    }

    // ── Content ───────────────────────────────────────────────
    // Llena bg (con clip y radius), no el padre directo, y no renderiza
    // bordes propios.
    MprisContent {
        id: mprisContent

        anchors.fill: bg
        currentPosition: root.currentPosition
        onSeekRequested: newPosition => {
            const p = MprisService.activePlayer;
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
