import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core

// Una ventana de fondo estático por pantalla (la crea WallpaperLayer).
// Transición en dos fases (idéntica siempre): fundido a negro rápido
// + fundido de entrada con zoom sutil. Sin fundido en negro = punto
// medio embarrado en pares de distinto brillo.
PanelWindow {
    id: root

    property string source: ""
    property bool frontIsA: true
    property string shownSource: ""

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
    
    component WallpaperImage: Image {
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
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
        duration: Appearance.motion.short4
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
        duration: Appearance.motion.long1
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
        duration: Appearance.motion.long1
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
        img.source = src !== "" ? Qt.resolvedUrl(src) : "";
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
            root.readyItem = img; // <-- FALTA ESTA LÍNEA
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
    Component.onCompleted: root.applyBg()

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
        // Fase 1: apagar lo visible; al terminar, beginHiddenLoad enciende
        // lo nuevo (si no hay nada visible, directo a fase 2).
        fadeIn.stop();
        zoomIn.stop();
        fadeOut.stop();
        root.clearReadyWait();
        root.pendingSrc = src;
        root.hasPending = true;
        if (root.shownSource !== "") {
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
