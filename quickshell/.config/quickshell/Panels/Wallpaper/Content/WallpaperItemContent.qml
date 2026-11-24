pragma ComponentBehavior: Bound

import qs.Primitives
import qs.Core
import qs.Core.Services as Services
import QtQuick

Item {
    id: root

    property int radius: 18
    property bool isSelected: false
    property bool hovered: false

    // Decodificado dimensionado para tarjetas altas (560x310) con compensación de shear (+0.28)
    // Acotar sourceSize acelera radicalmente el decodificado de imágenes grandes/4K
    property int imageWidth: 660
    property int imageHeight: 330

    required property string filePath

    property int delegateIndex: -1
    property int listCurrentIndex: -1
    readonly property bool isNear: delegateIndex < 0 || listCurrentIndex < 0 || Math.abs(delegateIndex
                                                                                         - listCurrentIndex)
                                   <= 6

    readonly property bool isVideo: Services.WallpaperService.isVideo(root.filePath)

    function maybeRequestFrame() {
        if (root.isVideo && root.isNear)
            Services.VideoFrameService.ensureFrame(root.filePath);
    }

    Component.onCompleted: root.maybeRequestFrame()

    onFilePathChanged: {
        root.maybeRequestFrame();
        // Carga inmediata de la fuente al reciclar delegado
        wallpaperPreview.source = Qt.resolvedUrl(root.thumbSource());
    }
    onIsNearChanged: root.maybeRequestFrame()
    onIsVideoChanged: root.maybeRequestFrame()

    // Para video devuelve directamente el frame estático: si ya existe en disco
    // se carga de inmediato en 0ms sin esperar a la cola de bash.
    function thumbSource(): string {
        return Services.WallpaperService.staticSourceFor(root.filePath);
    }

    // Si el frame se acaba de generar por ffmpeg en segundo plano, se refresca
    Connections {
        target: Services.VideoFrameService

        function onFrameReady(videoPath: string, framePath: string) {
            if (videoPath === root.filePath) {
                wallpaperPreview.source = "";
                wallpaperPreview.source = Qt.resolvedUrl(framePath);
            }
        }
    }

    // Icono placeholder mientras se carga (sin distorsión gracias al contra-shear)
    MaterialIcon {
        anchors.centerIn: parent
        icon: root.isVideo ? "movie" : "image"
        size: 36
        color: Appearance.md3.on_surface_variant
        opacity: 0.30
        visible: wallpaperPreview.status !== Image.Ready

        transform: [
            Matrix4x4 {
                matrix: Qt.matrix4x4(1, 0.28, 0, 0, 0, 1.0, 0, 0, 0, 0.0, 1, 0, 0, 0.0, 0, 1)
            }
        ]
    }

    // ── Tarjeta con borde adaptado a Matugen ───────────────────────────
    Rectangle {
        id: imageMask

        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        StyledClippingRectangle {
            anchors.fill: parent
            radius: root.radius
            border.color: root.isSelected ? Appearance.md3.primary : Qt.alpha(Appearance.md3.outline, 0.25)
            border.width: root.isSelected ? 2 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.motion.normal
                }
            }

            Image {
                id: wallpaperPreview

                // Sangría para compensar la inclinación oblicua del contenedor (-0.28)
                // y cubrir completamente la tarjeta con la imagen sin distorsión
                readonly property real shearBleed: Math.ceil(parent.height * 0.28)

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    leftMargin: -shearBleed - 8
                    rightMargin: -8
                }

                // Contra-shear en X de +0.28 para anular el shear de -0.28 del contenedor:
                // la imagen se proyecta totalmente recta (sin distorsión), mientras que
                // el marco/contenedor conserva su forma original de paralelogramo.
                transform: [
                    Matrix4x4 {
                        matrix: Qt.matrix4x4(1, 0.28, 0, 0, 0, 1.0, 0, 0, 0, 0.0, 1, 0, 0, 0.0, 0, 1)
                    }
                ]

                source: Qt.resolvedUrl(root.thumbSource())
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Sin caché global: evita retener pixmaps de muchas miniaturas.
                cache: false
                mipmap: true
                smooth: true
                sourceSize.width: root.imageWidth
                sourceSize.height: root.imageHeight
                opacity: status === Image.Ready ? 1 : 0

                scale: root.hovered ? 1.04 : 1.0

                Behavior on scale {
                    SpringAnimation {
                        spring: 2.5
                        damping: 0.20
                        mass: 0.7
                        epsilon: 0.003
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.motion.fast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Appearance.motion.standard
                    }
                }
            }

            // Insignia de video (sin distorsión gracias al contra-shear)
            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    margins: 12
                }
                width: badgeRow.implicitWidth + 14
                height: 22
                radius: 6
                color: Qt.alpha(Appearance.md3.surface_container_lowest, 0.75)
                border.color: Qt.alpha(Appearance.md3.primary, 0.40)
                border.width: 1
                visible: root.isVideo && wallpaperPreview.status === Image.Ready

                transform: [
                    Matrix4x4 {
                        matrix: Qt.matrix4x4(1, 0.28, 0, 0, 0, 1.0, 0, 0, 0, 0.0, 1, 0, 0, 0.0, 0, 1)
                    }
                ]

                Row {
                    id: badgeRow

                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "play_arrow"
                        size: 14
                        color: Appearance.md3.primary
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "VID"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Appearance.md3.primary
                    }
                }
            }

            // Badge "PIC" para imágenes estáticas (sin distorsión)
            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    margins: 12
                }
                width: picBadgeRow.implicitWidth + 14
                height: 22
                radius: 6
                color: Qt.alpha(Appearance.md3.surface_container_lowest, 0.75)
                border.color: Qt.alpha(Appearance.md3.primary, 0.40)
                border.width: 1
                visible: !root.isVideo && root.isSelected && wallpaperPreview.status === Image.Ready

                transform: [
                    Matrix4x4 {
                        matrix: Qt.matrix4x4(1, 0.28, 0, 0, 0, 1.0, 0, 0, 0, 0.0, 1, 0, 0, 0.0, 0, 1)
                    }
                ]

                Row {
                    id: picBadgeRow

                    anchors.centerIn: parent
                    spacing: 2

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "PIC"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: Appearance.md3.primary
                    }
                }
            }

            // State layer hover
            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.md3.on_surface
                opacity: root.hovered ? 0.05 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }

            // Scrim degradado inferior muy sutil
            Rectangle {
                id: nameScrim
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                height: parent.height * 0.32
                visible: root.isSelected && wallpaperPreview.status === Image.Ready

                gradient: Gradient {
                    orientation: Gradient.Vertical

                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.alpha(Appearance.md3.surface_container_lowest, 0.65)
                    }
                }
            }

            // Píldora inferior izquierda con el nombre de archivo (sin distorsión)
            Rectangle {
                anchors {
                    left: parent.left
                    leftMargin: 20
                    bottom: parent.bottom
                    bottomMargin: 14
                }
                width: Math.min(parent.width - 40, fileNameLabel.implicitWidth + 24)
                height: 24
                radius: 6
                color: Qt.alpha(Appearance.md3.surface_container_lowest, 0.70)
                border.color: Qt.alpha(Appearance.md3.outline_variant, 0.35)
                border.width: 1
                visible: root.isSelected && wallpaperPreview.status === Image.Ready

                transform: [
                    Matrix4x4 {
                        matrix: Qt.matrix4x4(1, 0.28, 0, 0, 0, 1.0, 0, 0, 0, 0.0, 1, 0, 0, 0.0, 0, 1)
                    }
                ]

                StyledText {
                    id: fileNameLabel

                    anchors.centerIn: parent
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideMiddle
                    text: {
                        const parts = root.filePath.split("/");
                        return parts.length > 0 ? parts[parts.length - 1] : "";
                    }
                    color: Appearance.md3.on_surface
                    font.pixelSize: Appearance.typeScale.labelSmall
                    font.weight: Font.Medium
                }
            }
        }
    }
}
