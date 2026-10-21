import qs.Primitives
import qs.Core
import qs.Core.Services as Services
import QtQuick

Item {
    id: root

    property int radius: Appearance.shape.windowRounding
    property bool isSelected: false
    property bool hovered: false

    // Decodificado acotado a ~1.35x del tamaño mostrado (300x220,
    // 324x238 con la escala de seleccionado): nítido sin desperdiciar
    // VRAM (antes 560x400, ~37% más por thumb).
    property int imageWidth: 440
    property int imageHeight: 320

    required property string filePath

    // Ventana de cercanía al viewport: el ListView instancia delegados
    // fuera de pantalla por el cacheBuffer, y pedir el frame de todos al
    // abrir el menú encolaba N ffmpeg de golpe. Solo piden frame los
    // cercanos al actual (±4); al hacer scroll entran en ventana y lo
    // piden entonces. El padre los ata a index/currentIndex.
    property int delegateIndex: -1
    property int listCurrentIndex: -1
    readonly property bool isNear: delegateIndex < 0 || listCurrentIndex < 0 || Math.abs(delegateIndex
                                                                                         - listCurrentIndex)
                                   <= 4

    readonly property bool isVideo: Services.WallpaperService.isVideo(root.filePath)

    function maybeRequestFrame() {
        if (root.isVideo && root.isNear)
            Services.VideoFrameService.ensureFrame(root.filePath);
    }

    // Los videos se representan por su frame (el Image no lee video). El
    // frame se pide al entrar en ventana; la cola del servicio serializa
    // las extracciones (un solo ffmpeg a la vez).
    // Puerta igual que el lockscreen: el Image no reintenta un fichero
    // ausente al primer intento, asi que la cadena solo se expone cuando
    // el servicio confirma (binding sobre `confirmed`, sin Connections).
    Component.onCompleted: root.maybeRequestFrame()

    // Los delegados se reciclan (pool del ListView): si cambia el archivo,
    // o si el scroll lo acerca al viewport, se pide su frame. Nunca desde
    // el binding de source (escribir durante su evaluacion dispara
    // "Binding loop detected").
    onFilePathChanged: root.maybeRequestFrame()
    onIsNearChanged: root.maybeRequestFrame()
    onIsVideoChanged: root.maybeRequestFrame()

    function thumbSource(): string {
        if (!root.isVideo)
            return root.filePath;
        // LECTURA PURA: "" -> frame es un cambio real que carga.
        const open = Services.VideoFrameService.confirmed[root.filePath] !== undefined;
        return open ? Services.WallpaperService.staticSourceFor(root.filePath) : "";
    }

    // Icono placeholder mientras se carga
    MaterialIcon {
        anchors.centerIn: parent
        icon: root.isVideo ? "movie" : "image"
        size: 32
        color: Appearance.md3.on_surface_variant
        opacity: Appearance.opacity.ghost
        visible: wallpaperPreview.status !== Image.Ready
    }

    // ── Imagen y Borde de Cristal ──────────────────────────────
    Rectangle {
        id: imageMask

        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        StyledClippingRectangle {
            anchors.fill: parent
            radius: root.radius
            border.color: root.isSelected ? Appearance.border.selected : Qt.alpha(Appearance.md3.on_surface,
                                                                                  0.12)
            border.width: root.isSelected ? Appearance.border.focusWidth : Appearance.border.width

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.motion.normal
                }
            }

            Image {
                id: wallpaperPreview

                anchors.fill: parent
                source: {
                    const eff = root.thumbSource();
                    return eff !== "" ? Qt.resolvedUrl(eff) : "";
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Thumbs locales: sin caché global para que el Loader al
                // destruir libere los pixmaps. Recarga rápida desde disco
                // con placeholder + fade ya existentes (sin parpadeo extra).
                cache: false
                sourceSize.width: root.imageWidth
                sourceSize.height: root.imageHeight
                opacity: status === Image.Ready ? 1 : 0

                scale: root.hovered ? 1.04 : 1.0

                Behavior on scale {
                    SpringAnimation {
                        spring: Appearance.motion.springSoft.spring
                        damping: Appearance.motion.springSoft.damping
                        mass: Appearance.motion.springSoft.mass
                        epsilon: Appearance.motion.springSoft.epsilon
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.motion.normal
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Appearance.motion.emphasized
                    }
                }
            }

            // Insignia de video (solo videos): indica fondo animado.
            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    margins: Appearance.spacing.medium
                }
                width: badgeIcon.implicitWidth + 14
                height: 24
                radius: Appearance.shape.medium
                color: Qt.rgba(0, 0, 0, 0.45)
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: Appearance.border.width
                visible: root.isVideo && wallpaperPreview.status === Image.Ready

                MaterialIcon {
                    id: badgeIcon

                    anchors.centerIn: parent
                    icon: "play_arrow"
                    size: 16
                    color: Qt.rgba(1, 1, 1, 0.95)
                }
            }

            // Capa de resaltado (State layer hover)
            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.md3.on_surface
                opacity: root.hovered ? 0.06 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }

            // Scrim degradado inferior (excepción intencionada: monocromo
            // sobre foto, igual en ambos temas).
            Rectangle {
                id: nameScrim
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                height: parent.height * 0.38
                visible: wallpaperPreview.status === Image.Ready

                gradient: Gradient {
                    orientation: Gradient.Vertical

                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(0, 0, 0, 0.70)
                    }
                }
            }

            // Píldora con el nombre de archivo
            Rectangle {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 10
                }
                width: Math.min(parent.width - 20, fileNameLabel.implicitWidth + 16)
                height: 24
                radius: Appearance.shape.medium
                color: Qt.rgba(0, 0, 0, 0.45)
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: Appearance.border.width
                visible: wallpaperPreview.status === Image.Ready

                StyledText {
                    id: fileNameLabel

                    anchors.centerIn: parent
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    text: {
                        const parts = root.filePath.split("/");
                        return parts.length > 0 ? parts[parts.length - 1] : "";
                    }
                    color: Qt.rgba(1, 1, 1, 0.95)
                    font.pixelSize: Appearance.typeScale.labelSmall
                    font.weight: Font.Medium
                }
            }
        }
    }
}
