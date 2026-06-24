import QtQuick
import Quickshell.Widgets
import qs.Primitives
import qs.Core

Item {
    id: root

    property int  radius:     16
    property bool isSelected: false
    property bool hovered:    false     // ← bool en vez de MouseArea

    // Icono placeholder mientras carga la imagen
    MaterialIcon {
        anchors.centerIn: parent
        icon: "image"
        size: 32
        color: Appearance.md3.on_surface_variant
        opacity: 0.3
        visible: wallpaperPreview.status !== Image.Ready
    }

    // ── Imagen con máscara y state layers ─────────────────────
    Rectangle {
        id: imageMask
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        ClippingRectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            border.color: Appearance.md3.primary
            border.width: root.isSelected ? 2 : 0

            Image {
                id: wallpaperPreview
                anchors.fill: parent
                source: "file://" + model.filePath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 560
                sourceSize.height: 400
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
            }

            // State layer — selección
            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.md3.primary
                opacity: root.isSelected ? 0.08 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
            }

            // State layer — hover
            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: Appearance.md3.on_surface
                opacity: root.hovered ? 0.08 : 0   // ← usa el bool
                Behavior on opacity {
                    NumberAnimation { duration: 100 }
                }
            }
        }
    }   // ← cierre de imageMask — faltaba este, causaba que selectionBadge quedara dentro

    // ── Badge de selección ────────────────────────────────────
    Rectangle {
        id: selectionBadge
        anchors {
            top: parent.top
            right: parent.right
            margins: 10
        }
        width: 28
        height: 28
        radius: 14
        color: Appearance.md3.primary_container
        border.width: 2
        border.color: Appearance.md3.primary

        opacity: root.isSelected ? 1 : 0
        scale: root.isSelected ? 1 : 0.4

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
        }
        Behavior on scale {
            NumberAnimation { duration: 300; easing.type: Easing.OutBack }
        }

        MaterialIcon {
            anchors.centerIn: parent
            icon: "check"
            size: 16
            color: Appearance.md3.on_primary_container
        }
    }
}
