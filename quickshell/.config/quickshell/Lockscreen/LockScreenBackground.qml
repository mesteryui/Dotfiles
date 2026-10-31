pragma ComponentBehavior: Bound

import qs.Core as Core
import qs.Core.Modules as Modules
import qs.Core.Services as Services
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Item {
    id: root

    anchors.fill: parent

    required property ShellScreen targetScreen

    readonly property bool isDark: Services.ConfigService.configs.appearance.darkMode

    readonly property bool useWallpaper: Services.ConfigService.configs.lockscreen.useWallpaper

    // Puerta del frame de video: el Image NO reintenta un fichero que aun
    // no existia al primer intento, y reevaluar con la misma cadena es
    // no-op. Por eso un video solo expone su frame cuando el servicio lo
    // confirma (ver confirmed): la cadena "" -> frame SI es un cambio real
    // y carga. Sin esto, el primer uso de un video dejaba la base opaca
    // para siempre.
    // La puerta es un BINDING sobre `confirmed` (notifica al reasignarse):
    // sin Connections ni nombres de senal. La peticion va por eventos
    // (ver requestFrame). LECTURA PURA en todo el camino.
    function currentStaticWallpaper(): string {
        try {
            const persisted = Modules.Persistent.persistence.currentWallpaper || "";
            if (!root.useWallpaper || persisted === "")
                return "";
            if (!Services.WallpaperService.isVideo(persisted))
                return persisted;
            const open = Services.VideoFrameService.confirmed[persisted] !== undefined;
            return open ? Services.WallpaperService.staticSourceFor(persisted) : "";
        } catch (e) {
            // Degradación deliberada a la base opaca (nunca negro, nunca
            // crash): el fondo es decorativo, el bloqueo debe funcionar.
            console.warn("[Lockscreen] fondo no disponible (" + e + "), uso base opaca");
            return "";
        }
    }

    // Peticion del frame por eventos (no desde el binding): al crearse, al
    // cambiar de fondo y al activar "usar fondo". Idempotente.
    function requestFrame() {
        const persisted = Modules.Persistent.persistence.currentWallpaper || "";
        if (persisted !== "" && Services.WallpaperService.isVideo(persisted))
            Services.VideoFrameService.ensureFrame(persisted);
    }

    Component.onCompleted: root.requestFrame()
    onUseWallpaperChanged: root.requestFrame()

    Connections {
        target: Modules.Persistent.persistence

        function onCurrentWallpaperChanged() {
            root.requestFrame();
        }
    }

    property real scrimAlpha: isDark ? 0.32 : 0.22
    // Blur clamp 0..1 (MultiEffect trabaja en ese rango; config trae 1.3
    // por defecto). Con 0 se apaga la capa offscreen completa.

    readonly property real blurAmount: Math.min(1, Math.max(0,
                                                            Services.ConfigService.configs.lockscreen.blurLevel))

    Item {
        id: background

        anchors.fill: parent
        // Offscreen solo si hay blur real: a fullscreen el FBO + blur 64px
        // es de lo más caro de la shell. Con blur 0 se pinta directo.
        layer.enabled: root.blurAmount > 0
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: root.blurAmount > 0
            // MultiEffect.blur trabaja en 0..1: se clamp el valor de
            // config (por defecto 1.3) para no romper la capa.
            blur: root.blurAmount
            // 64→32: mitad de coste, diferencia visual mínima a fullscreen.
            blurMax: 32
            blurMultiplier: 1
        }

        // ── Base opaca: nunca negro ───────────────────────────────
        // Primer frame garantizado mientras el resto carga.
        Rectangle {
            anchors.fill: parent
            color: Core.Appearance.md3.surface_dim
        }

        // ── Screencopy ────────────────────────────────────────────
        // Solo cuando useWallpaper es false. Con wallpaper activado no
        // se muestra nunca: durante su carga se ve la base opaca.
        // En Loader para no retener el buffer de screencopy cuando no se
        // usa (el lockscreen vive por pantalla y el ScreencopyView activo
        // cuesta aunque esté en visible:false).
        Loader {
            id: screencopyLoader

            anchors.fill: parent
            active: !root.useWallpaper
            asynchronous: true
            sourceComponent: screencopyComp
        }

        Component {
            id: screencopyComp

            ScreencopyView {
                anchors.fill: parent
                captureSource: root.targetScreen
            }
        }

        // ── Wallpaper, directo ────────────────────────────────────
        // Sin Loader ni fundidos: la imagen aparece tal cual en cuanto
        // está lista. Mientras carga se ve la base opaca (nunca negro,
        // nunca screencopy). Siempre estatico: imagen persistida o frame
        // del video (el lockscreen nunca reproduce video).
        Image {
            id: wallpaper

            anchors.fill: parent
            // Sin fondo elegido (instalación fresca) no se resuelve nada:
            // Qt.resolvedUrl("") apuntaría al propio directorio QML.
            source: {
                const chosen = root.currentStaticWallpaper();
                return chosen !== "" ? Qt.resolvedUrl(chosen) : "";
            }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // El lockscreen se destruye al desbloquear; con cache:true Qt
            // dejaba la imagen completa en la caché global tras el unlock.
            cache: false
            // Decodificar a píxeles físicos (lógicos × DPR): a 1600×1000
            // lógicos se veía blando en una pantalla 2880×1800. Con guarda
            // nula: targetScreen se inyecta tras crear el item.

            readonly property real dpr: root.targetScreen ? root.targetScreen.devicePixelRatio : 1
            sourceSize.width: root.targetScreen ? Math.round(root.targetScreen.width * dpr) : 1920
            sourceSize.height: root.targetScreen ? Math.round(root.targetScreen.height * dpr) : 1080
        }
    }

    // ── Scrim para legibilidad ──────────────────────────────────────
    // Capa oscura en tema oscuro / clara en tema claro, para asegurar
    // que el texto (on_surface, etc.) se lea bien sobre cualquier fondo.
    Rectangle {
        anchors.fill: parent
        color: root.isDark ? Qt.rgba(0, 0, 0, root.scrimAlpha) : Qt.rgba(1, 1, 1, root.scrimAlpha)
    }
}
