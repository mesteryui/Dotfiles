// MprisSeekBar — Seekbar multimedia M3 Expressive reutilizable.
// Unifica la pista de progreso antes duplicada entre el popup multimedia
// (Panels/MediaPlayer) y la tarjeta del lockscreen: mismo gesto (preview
// local + un único seek al soltar), misma posición optimista aguas arriba
// y mismos estados coherentes (LIVE / 0:00 / mm:ss).
//
// API:
//   position: segundos reales de reproducción (el llamador la ata al servicio).
//   length:   segundos totales; <= 0 = duración desconocida (sin fill).
//   canSeek:  el reproductor permite buscar (streams en directo: no).
//   showTimes / showBubble: visibilidad de tiempos y burbuja de arrastre.
//   wavy:     trazo ondulado M3E (parte reproducida) + cursor vertical.
//   playing:  con wavy, anima la fase de la onda solo al reproducir.
//   seekRequested(newPosition): único seek real del gesto (al soltar).
//   dragging: true mientras el dedo está sobre la pista.
import qs.Core
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

ColumnLayout {
    id: root

    property real position: 0
    property real length: 0
    property bool canSeek: false
    property bool showTimes: true
    property bool showBubble: true
    // Variante ondulada M3E del fill (reproductor y lockscreen): trazo
    // senoidal en la parte reproducida + cursor vertical en la cabeza.
    // Desactivada por defecto, el widget usa el fill plano.
    property bool wavy: false
    // Solo con wavy: desplaza la fase de la onda mientras suena.
    // En pausa (o durante el arrastre) la onda queda quieta.
    property bool playing: false

    readonly property bool dragging: seekArea.pressed

    signal seekRequested(real newPosition)

    spacing: Appearance.spacing.extraSmall

    function formatTime(seconds: real): string {
        if (!seconds || seconds <= 0 || isNaN(seconds))
            return "0:00";
        const totalSec = Math.floor(seconds);
        const h = Math.floor(totalSec / 3600);
        const m = Math.floor((totalSec % 3600) / 60);
        const s = totalSec % 60;

        if (h > 0) {
            return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2,
                                                                                                            "0");
        }
        return m + ":" + String(s).padStart(2, "0");
    }

    // Pista interactiva de cápsula
    Item {
        id: trackContainer

        Layout.fillWidth: true
        implicitHeight: 20

        readonly property real totalLength: root.length ?? 0

        readonly property real progressRatio: totalLength > 0 ? Math.min(1.0, Math.max(0.0, root.position
                                                                                       / totalLength)) : 0.0

        // Ratio bajo el dedo mientras se arrastra (-1 si no).
        property real dragRatio: -1

        // Fase 0..1 del segmento indeterminado (LIVE).
        property real indetPhase: 0

        // Geometría de la onda M3E (trazo ondulado opt-in): amplitud,
        // periodo y grosor del trazo.
        readonly property real waveAmp: 5

        readonly property real waveLen: 36

        readonly property real waveStroke: 4

        // Cursor vertical de la cabeza de reproducción.
        readonly property real headWidth: 3

        readonly property real headHeight: 18

        readonly property real headX: Math.max(0, Math.min(trackContainer.width - headWidth,
                                                           trackContainer.width * displayRatio - headWidth
                                                           / 2))

        // Ancho del trazo ondulado: acaba bajo el cursor, que tapa el
        // recorte vertical del clip.
        readonly property real waveWidth: Math.max(0, headX + headWidth / 2)

        // Path SVG del trazo: seno muestreado (sin cierre) con dos periodos
        // de margen para poder desplazar la fase sin reconstruirlo por
        // frame. Solo depende del ancho/alto del track (redimensiones); el
        // muestreo fino mantiene las crestas redondeadas con stroke suave.
        function wavePath(): string {
            const w = trackContainer.width + 2 * trackContainer.waveLen;
            if (w <= 0)
                return "";
            const amp = trackContainer.waveAmp;
            const len = trackContainer.waveLen;
            const cy = trackContainer.height / 2;
            const step = 2;
            let d = "M0 " + cy.toFixed(1);
            for (let x = step; x <= w; x += step) {
                const y = cy + amp * Math.sin(x * 2 * Math.PI / len);
                d += "L" + x.toFixed(1) + " " + y.toFixed(1);
            }
            return d;
        }

        SequentialAnimation on indetPhase {
            loops: Animation.Infinite
            running: indetSeg.visible

            NumberAnimation {
                from: 0
                to: 1
                duration: 1400
                easing.type: Easing.Linear
            }
        }

        // Lo que se pinta: en arrastre sigue al dedo (como end-4),
        // si no al progreso real. Sin duración conocida no hay fill.
        readonly property real displayRatio: totalLength > 0 ? (seekArea.pressed && dragRatio >= 0
                                                                ? dragRatio : progressRatio) : 0.0

        // Pista base (Capsule track).
        // Spec M3 progress-indicators: grosor 4dp, esquinas 50%,
        // indicador primary sobre track surface-container-highest.
        Rectangle {
            id: trackBg

            // En modo ondulado la pista plana solo se usa como fallback
            // indeterminado (LIVE / duración desconocida).
            visible: !root.wavy || trackContainer.totalLength <= 0
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: seekArea.pressed ? 8 : (seekArea.containsMouse ? 6 : 4)
            radius: height / 2
            color: Appearance.md3.surface_container_highest
            // El segmento indeterminado entra desde fuera: se recorta a los
            // confines de la pista (nunca asoma por los extremos).
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            // Pista activa (Fill) con stop-indicator M3 Expressive:
            // gap de 4dp antes del resto (desaparece al 100%). Solo modo
            // plano; con wavy el trazo ondulado vive fuera de trackBg.
            Rectangle {
                visible: !root.wavy
                width: Math.max(0, trackBg.width * trackContainer.displayRatio - (trackContainer.displayRatio
                                                                                  >= 0.999 ? 0 : 4))
                height: parent.height
                radius: parent.radius
                color: Appearance.md3.primary

                Behavior on width {
                    enabled: !seekArea.pressed

                    NumberAnimation {
                        duration: 80
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.motion.fast
                    }
                }
            }

            // Stop indicator M3 (determinate plano): círculo de 4dp al final
            // del track, en primary. Se oculta al 100%, sin duración conocida
            // y con fill ondulado (la onda no lleva stop).
            Rectangle {
                width: 4
                height: 4
                radius: Appearance.shape.full
                color: Appearance.md3.primary
                anchors.verticalCenter: parent.verticalCenter
                x: trackBg.width - width
                visible: !root.wavy && trackContainer.totalLength > 0 && trackContainer.displayRatio < 0.999
            }

            // Indeterminado M3 (LIVE / duración desconocida): segmento que
            // recorre la pista en bucle. Solo vive mientras no hay total.
            Rectangle {
                id: indetSeg

                visible: trackContainer.totalLength <= 0
                width: trackBg.width * 0.35
                height: parent.height
                radius: parent.radius
                color: Appearance.md3.primary
                x: -width + trackContainer.indetPhase * (trackBg.width + width)
            }
        }

        // Pista inactiva del modo ondulado: línea fina desde la cabeza
        // hasta el final (la parte reproducida no lleva línea, solo onda).
        Rectangle {
            visible: root.wavy && trackContainer.totalLength > 0
            x: trackContainer.headX + trackContainer.headWidth
            width: Math.max(0, trackContainer.width - x)
            height: 2
            radius: 1
            anchors.verticalCenter: parent.verticalCenter
            color: Appearance.md3.surface_container_highest
        }

        // Trazo ondulado M3E (opt-in): seno recortado al progreso. El
        // Shape abarca dos periodos extra y la fase se anima desplazando
        // su x (sin reconstruir el path por frame).
        Item {
            id: waveViewport

            visible: root.wavy && trackContainer.totalLength > 0
            width: trackContainer.waveWidth
            height: trackContainer.height
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Shape {
                id: waveShape

                width: trackContainer.width + 2 * trackContainer.waveLen
                height: waveViewport.height
                asynchronous: true

                ShapePath {
                    fillColor: "transparent"
                    strokeWidth: trackContainer.waveStroke
                    strokeColor: Appearance.md3.primary
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathSvg {
                        path: trackContainer.wavePath()
                    }
                }

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    // paused (no running) conserva la fase al pausar o
                    // arrastrar: al reanudar no salta al inicio del ciclo.
                    paused: !root.playing || seekArea.pressed

                    NumberAnimation {
                        from: 0
                        to: -trackContainer.waveLen
                        duration: 2600
                        easing.type: Easing.Linear
                    }
                }
            }
        }

        // Cursor vertical de la cabeza (siempre visible en modo ondulado;
        // crece ligeramente al pasar el ratón o arrastrar).
        Rectangle {
            id: progressHead

            visible: root.wavy && trackContainer.totalLength > 0
            x: trackContainer.headX
            width: trackContainer.headWidth
            height: trackContainer.headHeight + ((seekArea.containsMouse || seekArea.pressed) ? 4 : 0)
            radius: Appearance.shape.full
            anchors.verticalCenter: parent.verticalCenter
            color: Appearance.md3.primary

            Behavior on height {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Burbuja de tiempo al arrastrar (estilo end-4).
        Rectangle {
            id: seekBubble

            visible: root.showBubble && seekArea.pressed && trackContainer.dragRatio >= 0
                     && trackContainer.totalLength > 0
            width: bubbleText.implicitWidth + 20
            height: 26
            radius: Appearance.shape.full
            color: Appearance.md3.primary_container
            x: Math.max(0, Math.min(trackContainer.width - width, trackContainer.width
                                    * trackContainer.displayRatio - width / 2))
            y: -30

            StyledText {
                id: bubbleText

                anchors.centerIn: parent
                text: root.formatTime(trackContainer.dragRatio * trackContainer.totalLength)
                font.pixelSize: Appearance.typeScale.labelSmall
                font.family: Appearance.font.mono
                color: Appearance.md3.on_primary_container
            }
        }

        // Thumb — círculo simple (sin MaterialShape ni morph); aparece al hover.
        Rectangle {
            id: seekThumb

            x: Math.max(0, Math.min(trackContainer.width - width, trackContainer.width
                                    * trackContainer.displayRatio - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: width
            radius: width / 2
            color: Appearance.md3.primary
            opacity: (!root.wavy && (seekArea.containsMouse || seekArea.pressed)) ? 1 : 0
            scale: (!root.wavy && (seekArea.containsMouse || seekArea.pressed)) ? 1 : 0.5

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
            Behavior on scale {
                SpringAnimation {
                    spring: Appearance.motion.springSnappy.spring
                    damping: Appearance.motion.springSnappy.damping
                    mass: Appearance.motion.springSnappy.mass
                    epsilon: 0.005
                }
            }
            Behavior on x {
                enabled: !seekArea.pressed

                NumberAnimation {
                    duration: 80
                }
            }
        }

        MouseArea {
            id: seekArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor

            // Vista previa local bajo el dedo (sin tocar D-Bus).
            function previewSeek(mouseX: real) {
                if (!root.canSeek || trackContainer.totalLength <= 0)
                    return;
                trackContainer.dragRatio = Math.max(0.0, Math.min(1.0, mouseX / width));
            }

            // Único seek real del gesto: al soltar (también cubre el tap).
            function commitSeek(mouseX: real) {
                if (!root.canSeek || trackContainer.totalLength <= 0)
                    return;
                const ratio = Math.max(0.0, Math.min(1.0, mouseX / width));
                trackContainer.dragRatio = ratio;
                root.seekRequested(ratio * trackContainer.totalLength);
            }

            onPressed: mouse => previewSeek(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    previewSeek(mouse.x);
            }
            onReleased: mouse => {
                commitSeek(mouse.x);
                trackContainer.dragRatio = -1;
            }
            onCanceled: trackContainer.dragRatio = -1
        }
    }

    // Tiempos
    RowLayout {
        Layout.fillWidth: true
        visible: root.showTimes

        StyledText {
            // Durante el arrastre muestra la posición del dedo (igual que
            // la burbuja), si no la posición real de reproducción.
            text: (seekArea.pressed && trackContainer.dragRatio >= 0 && trackContainer.totalLength > 0)
                  ? root.formatTime(trackContainer.dragRatio * trackContainer.totalLength) : root.formatTime(
                        root.position)
            font.pixelSize: Appearance.typeScale.labelSmall
            font.family: Appearance.font.mono
            font.features: ({
                                "tnum": 1
                            })
            color: Appearance.md3.on_surface_variant
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            // Sin duración conocida: directo no buscable → "LIVE";
            // buscable aún sin total (cambio de pista) → "0:00".
            text: trackContainer.totalLength > 0 ? root.formatTime(root.length) : (root.canSeek ? "0:00" :
                                                                                                  "LIVE")
            font.pixelSize: Appearance.typeScale.labelSmall
            font.family: Appearance.font.mono
            font.features: ({
                                "tnum": 1
                            })
            color: Appearance.md3.on_surface_variant
        }
    }
}
