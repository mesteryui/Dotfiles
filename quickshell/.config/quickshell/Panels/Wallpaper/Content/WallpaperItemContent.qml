import qs.Primitives
import qs.Core
import QtQuick
import Quickshell.Widgets

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

    // Icono placeholder mientras se carga
    MaterialIcon {
        anchors.centerIn: parent
        icon: "image"
        size: 32
        color: Appearance.md3.on_surface_variant
        opacity: 0.3
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
            border.color: root.isSelected ? Appearance.md3.primary : Qt.rgba(1, 1, 1, 0.12)
            border.width: root.isSelected ? 2 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.motion.short4
                }
            }

            Image {
                id: wallpaperPreview

                anchors.fill: parent
                source: Qt.resolvedUrl(root.filePath)
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
                    NumberAnimation {
                        duration: Appearance.motion.medium2
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.motion.short4
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Appearance.motion.emphasized
                    }
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

            // Scrim degradado inferior
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
                radius: Appearance.shape.small
                color: Qt.rgba(0, 0, 0, 0.45)
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
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
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }
        }
    }
}
