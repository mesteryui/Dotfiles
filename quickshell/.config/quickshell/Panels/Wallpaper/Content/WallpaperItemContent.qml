import QtQuick
import Quickshell.Widgets
import qs.Primitives
import qs.Core

Item {
    id: root

    property int radius: 18
    property bool isSelected: false
    property bool hovered: false

    property int imageWidth: 560
    property int imageHeight: 400

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
                    duration: 200
                }
            }

            Image {
                id: wallpaperPreview
                anchors.fill: parent
                source: Qt.resolvedUrl(root.filePath)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: root.imageWidth
                sourceSize.height: root.imageHeight
                opacity: status === Image.Ready ? 1 : 0

                scale: root.hovered ? 1.04 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
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
                radius: 12
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
