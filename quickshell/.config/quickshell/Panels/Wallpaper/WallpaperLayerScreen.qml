pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

// Una ventana de fondo por pantalla (la crea WallpaperLayer).
//
// Cambio de fondo: UN solo fundido, sin fases ni tokens.
//
//   1. la entrante se carga en la cara `back` (siempre la de encima);
//   2. al estar decodificada sube a opacidad 1 sobre la visible (`front`);
//   3. al terminar el fundido las caras se intercambian y la vieja se
//      libera (su textura deja de ocupar VRAM).
//
// Un cambio a mitad de fundido sustituye la entrante en sitio: la visible
// sigue debajo, así que nunca queda un hueco (ni un flash de superficie
// vacía).
//
// La ENTRADA de la ventana la pone el compositor: la regla de layer de
// Hyprland para el namespace "quickshell:wallpaper-layer" es
// `animation = fade`, así que la ventana no se mapea hasta que hay
// contenido decodificado y ese fade entra sobre una imagen ya lista. En
// QML solo queda el fundido entre fondos.
PanelWindow {
    id: root

    property string source: ""
    property int windowsOnWorkspace: 0

    // Cara visible y cara entrante del doble buffer. `back` va siempre por
    // encima (`z`): al intercambiar las caras se reordena.
    property Image front: imgA
    property Image back: imgB

    // URL de lo que se quiere mostrar. Puede diferir de la visible
    // mientras la entrante carga.
    property url desiredUrl: ""

    // URL de lo que hay en pantalla ahora.
    property url shownUrl: ""

    // Banderas de estado (NO se derivan de `Image.status`: al mapearse la
    // ventana cambian `sourceSize` y la imagen vuelve a decodificar durante
    // un instante; si la ventana dependiera del status, se cerraría y
    // abriría en bucle).
    //
    // - posterReady: el póster está decodificado y se puede pintar.
    // - mapped: la ventana ya se mostró una vez (desde entonces no se
    //   cierra nunca: los cambios los hace QML, no el compositor).
    // - animated: los behaviors de fundido/zoom están activos (tras el
    //   primer pintado).
    property bool posterReady: false
    property bool mapped: false
    property bool animated: false

    readonly property bool videoReady: videoLoader.item?.hasVideo ?? false
    readonly property bool contentReady: root.posterReady || root.videoReady

    visible: root.source !== "" && (root.mapped || root.contentReady)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell:wallpaper-layer"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onVisibleChanged: {
        // No escribimos `mapped` aquí: `visible` es un binding que también
        // depende de `mapped`, así que escribirlo desde su propio change
        // handler crea un binding loop ("Binding loop detected for property
        // visible"). El armado del flag se hace en las transiciones de
        // contenido (Connections / Loader), que son los puntos reales.
        if (root.visible) {
            root.animated = true;
        }
    }

    // Soltar un fichero de imagen o video sobre el fondo lo pone como
    // wallpaper (pasa por validacion + persistencia + fundido de applyBg).
    DropArea {
        anchors.fill: parent

        onEntered: drag => {
            if (drag.hasUrls || drag.hasText)
                drag.accepted = true;
        }
        onDropped: drop => root.handleDrop(drop)
    }

    component WallpaperImage: Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        // Mipmap: el zoom 1.04→1 y el crop reescalan cada frame; sin
        // mipmaps el filtrado tiembla y rinde peor en la animación.
        mipmap: true
        // targetScale acota el decodado a los píxeles físicos de la
        // pantalla (lógicos × DPR). Se limita a 2 como máximo: por encima
        // no se gana nitidez visible y solo se inflan las texturas.
        // El DPR sale de la pantalla quefills el delegate (no de
        // `Screen.devicePixelRatio`, que solo se resuelve al mapear la
        // ventana: eso cambiaría el tamaño de decodado en pleno fundido).

        readonly property real targetScale: Math.min(2, Math.max(1, root.screen
                                                                 ? root.screen.devicePixelRatio : 1))
        sourceSize.width: Math.round((root.screen ? root.screen.width : 1920) * targetScale)
        sourceSize.height: Math.round((root.screen ? root.screen.height : 1080) * targetScale)

        // Fundido de entrada y zoom: solo tras el primer pintado.
        Behavior on opacity {
            enabled: root.animated

            NumberAnimation {
                duration: Appearance.motion.normal
                easing.type: Easing.Bezier
                easing.bezierCurve: Appearance.motion.standard
            }
        }
        Behavior on scale {
            enabled: root.animated

            SpringAnimation {
                spring: Appearance.motion.springSnappy.spring
                damping: Appearance.motion.springSnappy.damping
                mass: Appearance.motion.springSnappy.mass
                epsilon: Appearance.motion.springSnappy.epsilon
            }
        }
    }

    // Control del deck frost: vive aparte del wallpaper. Si se elimina este
    // bloque, el wallpaper sigue igual; solo hay que quitar las dos líneas
    // `layer` de wallpaperPlane para dejar de aplicar el efecto.
    WallpaperFrostController {
        id: frost

        windowsOnWorkspace: root.windowsOnWorkspace
        videoActive: root.isVideoTarget
    }

    // Contenedor exclusivo del fondo. La capa solo se enciende mientras el
    // frost está activo (ventana abierta, modo permitido, etc.); con el
    // ajuste apagado renderiza directamente, sin FBO ni MultiEffect.
    Item {
        id: wallpaperPlane

        anchors.fill: parent
        // Con fondo de vídeo en reproducción no tiene sentido mantener el
        // FBO de desenfoque: cada frame costaría GPU desenfocando contenido
        // que ya se mueve. Se apaga inmediatamente (sin esperar a que el
        // Behavior de `blur` llegue a 0, que tarda ~200ms).
        layer.enabled: frost.active && !root.videoEnabled
        layer.effect: WallpaperFrostEffect {
            amount: frost.blur
            maxRadius: frost.blurMax
        }

        // imgA debajo, imgB encima. `z` se reordena al intercambiar las
        // caras para que la entrante quede siempre por encima de la visible.
        WallpaperImage {
            id: imgA

            z: 0
            opacity: 1
        }

        WallpaperImage {
            id: imgB

            z: 1
            opacity: 0
        }
    }

    // ── Cambio de fondo ────────────────────────────────────────────────
    // URL de la imagen estática que representa a `src`: para un vídeo, su
    // frame extraído (el póster). Pide el frame si aún no existe.
    function staticUrl(src) {
        if (Services.WallpaperService.isVideo(src)) {
            Services.VideoFrameService.ensureFrame(src);
            return Qt.resolvedUrl(Services.WallpaperService.staticSourceFor(src));
        }
        return Qt.resolvedUrl(src);
    }

    // Carga la entrante en la cara `back`. Si ya está visible o en camino,
    // no hace nada (evita re-decodificar al reaplicar el mismo fondo).
    function applyBg() {
        const src = root.source;
        if (src === "") {
            root.desiredUrl = "";
            root.shownUrl = "";
            root.posterReady = false;
            root.mapped = false;
            root.front.source = "";
            root.back.source = "";
            root.front.opacity = 1;
            root.front.scale = 1;
            root.back.opacity = 0;
            return;
        }
        const url = root.staticUrl(src);
        if (String(url) === String(root.desiredUrl))
            return;
        root.desiredUrl = url;
        root.posterReady = false;
        fadeTimer.stop();
        root.back.source = url;
        root.back.opacity = 0;
        root.back.scale = 1.04;
    }

    // Fin del fundido: la entrante pasa a ser la visible y la vieja se
    // libera (su textura deja de ocupar VRAM).
    function commit() {
        const old = root.front;
        root.shownUrl = root.back.source;
        // La vieja se vacía ANTES de subirla: si no, un frame de la textura
        // vieja tapando la nueva.
        old.source = "";
        root.front = root.back;
        root.back = old;
        // La entrante queda arriba (z) para el siguiente fundido.
        root.front.z = 0;
        root.back.z = 1;
        root.back.opacity = 0;
        root.back.scale = 1;
    }

    // El fundido dura `Appearance.motion.normal`; el margen cubre el final
    // del Behavior antes de liberar la cara vieja.
    Timer {
        id: fadeTimer

        interval: Appearance.motion.normal + 50
        repeat: false
        onTriggered: {
            if (root.back.status === Image.Ready)
                root.commit();
        }
    }

    Connections {
        target: root.back

        function onStatusChanged() {
            if (root.back.status !== Image.Ready)
                return;
            // Es la carga que se pidió: si no, es un frame viejo que llegó
            // tarde (el `desiredUrl` manda).
            if (String(root.back.source) !== String(root.desiredUrl))
                return;
            root.posterReady = true;
            // El póster ya está decodificado: la condición de `visible`
            // (`source !== "" && (mapped || contentReady)`) se cumple, así que
            // armamos la ventana. Se escribe aquí (transición de contenido) y
            // no en onVisibleChanged para no crear el ciclo visible<->mapped.
            root.mapped = true;
            // Ya está en pantalla (p. ej. la imagen se re-decodifica al
            // cambiar de tamaño): no hay nada que fundir.
            if (String(root.back.source) === String(root.shownUrl))
                return;
            root.back.opacity = 1;
            root.back.scale = 1;
            if (root.animated)
                fadeTimer.restart();
            else
                root.commit();
        }
    }

    onSourceChanged: root.applyBg()

    Component.onCompleted: {
        if (root.isVideoTarget)
            Services.VideoSupport.ensureProbed();
        root.applyBg();
    }

    // Soltar un fichero de imagen o video sobre el fondo lo pone como
    // wallpaper (pasa por validacion + persistencia + fundido de applyBg).
    function handleDrop(drop) {
        let raw = "";
        if (drop.hasUrls && drop.urls.length > 0)
            raw = String(drop.urls[0]);
        else if (drop.hasText && drop.text)
            raw = String(drop.text).split("\n")[0].trim();
        if (raw === "")
            return;
        const path = decodeURIComponent(raw.replace(/^file:\/\//, "")).trim();
        if (Services.WallpaperService.validAny(path))
            Services.WallpaperService.apply(path);
    }

    // ── Capa de vídeo (opcional) ───────────────────────────────────────
    // Solo existe mientras el fondo objetivo es un video con soporte. Carga
    // aislada por URL (nunca tipo estatico): si QtMultimedia falta o el
    // archivo falla, solo este Loader da Error y queda el poster estatico
    // del fundido. La shell nunca rompe.
    readonly property bool isVideoTarget: Services.WallpaperService.isVideo(root.source)

    readonly property bool videoEnabled: root.isVideoTarget && Services.VideoSupport.available

    // Sonda lazy: solo un fondo vídeo carga QtMultimedia al proceso. El
    // arranque estático nunca llega aquí.
    onIsVideoTargetChanged: {
        if (root.isVideoTarget)
            Services.VideoSupport.ensureProbed();
    }

    // Gracia de descarga: al bloquear o entrar en juego el reproductor se
    // pausa (frame congelado) 1.5s por si es breve; pasado ese tiempo el
    // Loader se desactiva y el pipeline GStreamer se libera (~20MB). Al
    // desbloquear se recarga y reanuda solo. Sin esto, un vídeo pausado
    // retenía decodificador + buffers indefinidamente aunque tapado.
    Timer {
        id: unloadGrace

        interval: 1500
        repeat: false
        // Al expirar, el binding de `active` descarga el Loader en este
        // mismo tick: se para ordenado ANTES para soltar el decodificador
        // con los objetos aún vivos (ver stop()).
        onTriggered: {
            if (!root.wantPlaying && videoLoader.item && typeof videoLoader.item.stop === "function")
                videoLoader.item.stop();
        }
    }
    onWantPlayingChanged: {
        if (root.wantPlaying) {
            unloadGrace.stop();
        } else if (root.videoEnabled) {
            unloadGrace.restart();
        }
    }

    onVideoEnabledChanged: {
        if (!root.videoEnabled) {
            unloadGrace.stop();
            // Cambio vídeo→estático: parada ordenada antes de que el
            // binding de `active` desmonte el reproductor.
            if (videoLoader.item && typeof videoLoader.item.stop === "function")
                videoLoader.item.stop();
        }
    }

    Loader {
        id: videoLoader

        anchors.fill: parent
        active: root.videoEnabled && (root.wantPlaying || unloadGrace.running)
        asynchronous: true
        // Fundido solo con imagen real: mientras el reproductor abre el
        // archivo se ve el poster estatico del fundido. En pausa breve (modo
        // juego, <1.5s) se conserva el ultimo frame congelado; pasada la
        // gracia el Loader se descarga y se vuelve al poster: por eso se
        // usa hasVideo y no isPlaying.
        opacity: status === Loader.Ready && (item?.hasVideo ?? false) ? 1 : 0
        source: "AnimatedWallpaperPlayer.qml"
        onStatusChanged: {
            // Video listo y decodificado: armamos la ventana (la condición
            // de `visible` se cumple vía contentReady). Mismo criterio con el
            // `opacity` de arriba, así que el armado y el mostrar coinciden.
            if (status === Loader.Ready && videoLoader.item && videoLoader.item.hasVideo)
                root.mapped = true;
            if (status === Loader.Error)
                console.warn("[Wallpaper] no se pudo reproducir el video, uso poster estatico: "
                             + root.source);
        }
        // Asignación inmediata al cargar (sin esperar al Binding): cubre
        // la primera puesta del fondo.
        onLoaded: {
            if (videoLoader.item) {
                videoLoader.item.videoSource = Qt.resolvedUrl(root.source);
                videoLoader.item.playing = root.wantPlaying;
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.motion.normal
                easing.type: Easing.Bezier
                easing.bezierCurve: Appearance.motion.standard
            }
        }
    }

    // Fuente reactiva para el reproductor (cubre cambios video->video sin
    // recargar el Loader). Usamos `Connections` con `target: root` en vez de
    // `Binding { target: videoLoader.item }`: cuando el Loader se descarga y
    // vuelve a cargar, el `item` cambia y un `Binding` apuntando al `item`
    // viejo quedaría colgado y no se reanudaría sobre el nuevo. Las conexiones
    // a `root` sí se limpian solas al destruir el componente.
    Connections {
        target: root

        function onSourceChanged() {
            if (videoLoader.status === Loader.Ready && videoLoader.item)
                videoLoader.item.videoSource = Qt.resolvedUrl(root.source);
        }

        function onWantPlayingChanged() {
            if (videoLoader.status === Loader.Ready && videoLoader.item)
                videoLoader.item.playing = root.wantPlaying;
        }
    }

    // Intención de reproducción en un solo sitio (onLoaded + vigilante +
    // conexiones de arriba): pausa en modo juego y bajo la pantalla de
    // bloqueo (ahí el vídeo queda totalmente tapado: decodificar es 100%
    // desperdicio). Al desbloquear reanuda solo.
    readonly property bool wantPlaying: !Services.GameMode.enabled && !Services.LockState.locked

    // Vigilante de reproducción: si el backend se queda clavado en pausa
    // (o un Binding se pierde entre recargas), re-emite play. Solo corre
    // con vídeo activo Y con intención de reproducir: en bloqueo/juego no
    // despierta el backend cada 6s. Nunca reproduce en modo juego ni
    // bloqueado.
    Timer {
        interval: 6000
        repeat: true
        running: root.videoEnabled && root.wantPlaying
        onTriggered: {
            if (!root.wantPlaying)
                return;
            const p = videoLoader.item;
            if (p && typeof p.play === "function" && !p.isPlaying)
                p.play();
        }
    }

    Connections {
        // El poster pudo intentar cargar antes de que el frame existiera
        // (Image no reintenta solo). Si la cara visible aun no esta lista
        // cuando el frame termina, se recarga (aqui el contexto es
        // imperativo: "" -> frame fuerza la recarga sin romper bindings).
        target: Services.VideoFrameService

        function onFrameReady(videoPath) {
            if (videoPath !== root.source || !root.isVideoTarget)
                return;
            root.back.source = "";
            root.back.source = Qt.resolvedUrl(Services.WallpaperService.staticSourceFor(videoPath));
        }
    }
}
