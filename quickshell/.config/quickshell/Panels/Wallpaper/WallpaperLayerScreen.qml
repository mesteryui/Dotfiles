pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import QtQuick
import Quickshell
import Quickshell.Wayland

// Una ventana de fondo estático por pantalla (la crea WallpaperLayer).
// Transición en dos fases (idéntica siempre): fundido a negro rápido
// + fundido de entrada con zoom sutil. Sin fundido en negro = punto
// medio embarrado en pares de distinto brillo.
PanelWindow {
    id: root

    property string source: ""
    property bool frontIsA: true
    property string shownSource: ""
    // Primera puesta: directa, sin transición de arranque.
    property bool isInitialLoad: true

    visible: root.source !== ""
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

    // Soltar un fichero de imagen pone ese fondo (ver handleDrop).
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
        // Decodificar acotado a la pantalla EN PÍXELES FÍSICOS (lógicos ×
        // DPR): con solo screen.width en HiDPI 200% un fondo se decodifica
        // a 1920 y el compositor lo estira a 3840 físicos = imagen blanda.
        // Sin esto un wallhaven de 17MB se decodifica entero (~30MB de
        // textura por cara, x2 en fundido). Patrón igual que lockscreen.

        readonly property real targetScale: Math.max(1, Screen.devicePixelRatio)
        sourceSize.width: Math.round((root.screen ? root.screen.width : 1920) * targetScale)
        sourceSize.height: Math.round((root.screen ? root.screen.height : 1080) * targetScale)
    }

    WallpaperImage {
        id: imgA

        opacity: 1
    }

    WallpaperImage {
        id: imgB

        opacity: 0
    }

    // NOTA: el target se asigna imperativo en start/stop, NUNCA por
    // binding (`target: fadeX.targetImage` se reevalúa diferido y el
    // start() corría con el target viejo: fundidos muertos al nacer).
    NumberAnimation {
        id: fadeOut

        property Image targetImage

        property: "opacity"
        to: 0
        duration: Appearance.motion.normal
        easing.type: Easing.Bezier
        easing.bezierCurve: Appearance.motion.standard
        onFinished: {
            if (fadeOut.targetImage)
                root.beginHiddenLoad();
        }
    }
    NumberAnimation {
        id: fadeIn

        property Image targetImage

        property: "opacity"
        to: 1
        duration: Appearance.motion.slowest
        easing.type: Easing.Bezier
        easing.bezierCurve: Appearance.motion.standard
        onFinished: {
            if (!fadeIn.targetImage)
                return;
            const shown = fadeIn.targetImage === imgA ? imgB : imgA;
            shown.opacity = 0;
            shown.scale = 1.04;
            shown.source = "";
            root.frontIsA = fadeIn.targetImage === imgA;
        }
    }
    NumberAnimation {
        id: zoomIn

        property Image targetImage

        property: "scale"
        to: 1
        duration: Appearance.motion.slowest
        easing.type: Easing.Bezier
        easing.bezierCurve: Appearance.motion.standard
    }

    // Espera de decodificado con token anti-carreras (ver beginFade).
    // Se guarda el item para desconectar de verdad (si no, las conexiones
    // obsoletas se acumulan en los Image, que viven siempre).
    property int readyToken: 0

    property var readyItem: null

    property var readyHandler: null

    function clearReadyWait() {
        if (root.readyItem && root.readyHandler) {
            try {
                root.readyItem.statusChanged.disconnect(root.readyHandler);
            } catch (e) {}
        }
        root.readyItem = null;
        root.readyHandler = null;
    }

    function setHiddenSource(img, src) {
        // El fundido siempre trabaja con imagen estatica: un video se
        // representa por su frame (poster mientras carga el reproductor y
        // fallback si falla). Se pide el frame aqui para que exista ASAP.
        if (Services.WallpaperService.isVideo(src))
            Services.VideoFrameService.ensureFrame(src);
        const eff = Services.WallpaperService.staticSourceFor(src);
        img.source = eff !== "" ? Qt.resolvedUrl(eff) : "";
    }

    // Capa de video (opcional): solo existe mientras el fondo objetivo es
    // un video con soporte. Carga aislada por URL (nunca tipo estatico):
    // si QtMultimedia falta o el archivo falla, solo este Loader da Error
    // y queda el poster estatico del fundido. La shell nunca rompe.
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
                duration: Appearance.motion.slowest
                easing.type: Easing.Bezier
                easing.bezierCurve: Appearance.motion.standard
            }
        }
    }

    // Fuente reactiva para el reproductor (cubre cambios video->video sin
    // recargar el Loader).
    Binding {
        target: videoLoader.item
        property: "videoSource"
        value: root.videoEnabled ? Qt.resolvedUrl(root.source) : ""
        when: videoLoader.status === Loader.Ready
    }

    // Intención de reproducción en un solo sitio (binding + onLoaded +
    // vigilante la comparten): pausa en modo juego y bajo la pantalla de
    // bloqueo (ahí el vídeo queda totalmente tapado: decodificar es 100%
    // desperdicio). Al desbloquear reanuda solo.
    readonly property bool wantPlaying: !Services.GameMode.enabled && !Services.LockState.locked

    // Pausa en modo juego y en bloqueo: el video se congela en el ultimo
    // frame y reanuda solo al salir.
    Binding {
        target: videoLoader.item
        property: "playing"
        value: root.wantPlaying
        when: videoLoader.status === Loader.Ready
    }

    // Vigilante de reproducción: si el backend se queda clavado en pausa
    // (o un Binding se pierde entre recargas), re-emite play. Solo corre
    // con vídeo activo Y con intención de reproducir: en bloqueo/juego no
    // despierta el backend cada 3s. Nunca reproduce en modo juego ni
    // bloqueado.
    Timer {
        interval: 3000
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
        // La espera de fundido pendiente (beginFade) sigue conectada y
        // completa la transicion al llegar a Ready.
        target: Services.VideoFrameService

        function onFrameReady(videoPath) {
            if (videoPath !== root.source || !root.isVideoTarget)
                return;
            const front = root.frontIsA ? imgA : imgB;
            if (front.status !== Image.Ready) {
                front.source = "";
                root.setHiddenSource(front, root.source);
            }
        }
    }

    // Soltar un fichero de imagen o video sobre el fondo lo pone como
    // wallpaper (pasa por validacion + persistencia + crossfade de applyBg).
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

    // Arranca el fundido; si aún decodifica, espera al Ready (una vez).
    function beginFade(img) {
        const token = ++root.readyToken;
        root.clearReadyWait();
        if (img.status !== undefined && img.status !== Image.Ready) {
            const handler = () => {
                if (token !== root.readyToken)
                    return;
                if (img.status === Image.Ready) {
                    root.clearReadyWait();
                    root.startFade(img);
                }
            };
            root.readyHandler = handler;
            root.readyItem = img;
            img.statusChanged.connect(handler);
            if (img.status === Image.Ready) {
                root.clearReadyWait();
                root.startFade(img);
            }
            return;
        }
        root.startFade(img);
    }

    function startFade(img) {
        img.opacity = 0;
        img.scale = 1.04;
        fadeIn.targetImage = img;
        zoomIn.targetImage = img;
        // Asignación imperativa (ver nota arriba): el binding diferido
        // llegaría tarde al start().
        fadeIn.target = img;
        zoomIn.target = img;
        fadeIn.start();
        zoomIn.start();
    }

    onSourceChanged: root.applyBg()

    Component.onCompleted: {
        if (root.isVideoTarget)
            Services.VideoSupport.ensureProbed();
        root.applyBg();
    }

    // Petición pendiente mientras se apaga el actual.
    property string pendingSrc: ""

    property bool hasPending: false

    // Carga inicial + cambios: los handlers onXChanged no se disparan
    // con el valor inicial del binding, sin esto quedaría vacío.
    function applyBg() {
        const src = root.source;
        if (src === root.shownSource) {
            // Ya visible (o en camino): parar un apagado heredado y
            // reponer el frontal, sin tocar la espera de decodificado.
            fadeOut.stop();
            const front = root.frontIsA ? imgA : imgB;
            front.opacity = 1;
            root.hasPending = false;
            return;
        }
        if (src === "") {
            root.clearReadyWait();
            fadeIn.stop();
            zoomIn.stop();
            fadeOut.stop();
            root.hasPending = false;
            imgA.source = "";
            imgB.source = "";
            imgA.opacity = 1;
            imgB.opacity = 0;
            root.frontIsA = true;
            root.shownSource = "";
            return;
        }
        // Arranque: sin transición, puesta directa.
        if (root.isInitialLoad) {
            root.isInitialLoad = false;
            fadeIn.stop();
            zoomIn.stop();
            fadeOut.stop();
            root.clearReadyWait();
            root.hasPending = false;
            const first = root.frontIsA ? imgB : imgA;
            const prev = root.frontIsA ? imgA : imgB;
            root.setHiddenSource(first, src);
            first.opacity = 1;
            first.scale = 1;
            prev.opacity = 0;
            prev.source = "";
            root.frontIsA = !root.frontIsA;
            root.shownSource = src;
            return;
        }
        // Interrumpido a mitad de transición: degradar a fundido simple
        // (directo a fase 2, sin apagar a medias).
        const interrupted = fadeOut.running || fadeIn.running;
        // Fase 1: apagar lo visible; al terminar, beginHiddenLoad enciende
        // lo nuevo (si no hay nada visible o venía interrumpido: directo).
        fadeIn.stop();
        zoomIn.stop();
        fadeOut.stop();
        root.clearReadyWait();
        root.pendingSrc = src;
        root.hasPending = true;
        if (root.shownSource !== "" && !interrupted) {
            const front = root.frontIsA ? imgA : imgB;
            fadeOut.targetImage = front;
            fadeOut.target = front;
            fadeOut.start();
        } else {
            root.beginHiddenLoad();
        }
    }

    // Fase 2: cargar lo pendiente en la imagen oculta y fundirlo al estar
    // decodificada (ver beginFade). Sin nada pendiente: no-op.
    function beginHiddenLoad() {
        if (!root.hasPending)
            return;
        const src = root.pendingSrc;
        root.hasPending = false;
        if (src === "")
            return;
        const hidden = root.frontIsA ? imgB : imgA;
        root.setHiddenSource(hidden, src);
        root.beginFade(hidden);
        root.shownSource = src;
    }
}
