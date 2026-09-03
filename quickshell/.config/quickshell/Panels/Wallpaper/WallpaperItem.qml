pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.Panels.Wallpaper.Content
import qs.Core
import qs.Shared.Background

Item {
    id: delegateRoot

    required property var modelData
    required property int index

    signal clicked

    property int surfaceRadius: 18
    readonly property bool isSelected: ListView.isCurrentItem

    implicitWidth: 300
    implicitHeight: 220

    // Transformación Coverflow: Escala, transparencia e índice Z según selección
    scale: isSelected ? 1.08 : 0.86
    opacity: isSelected ? 1.0 : 0.60
    z: isSelected ? 10 : (100 - Math.abs(ListView.view.currentIndex - index))

    Behavior on scale {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    // ── Fondo y Sombra Elevada ──────────────────────────────────────────────
    SurfaceBackground {
        id: background
        anchors.fill: parent
        radius: delegateRoot.surfaceRadius
        color: delegateRoot.isSelected ? Appearance.md3.surface_container_highest : Appearance.md3.surface_container_low
    }

    // ── Contenido de la Tarjeta ─────────────────────────────────────────────
    WallpaperItemContent {
        anchors.fill: parent
        isSelected: delegateRoot.isSelected
        hovered: mouse.containsMouse
        radius: delegateRoot.surfaceRadius
        filePath: delegateRoot.modelData?.filePath ?? ""
    }

    // ── Captura de Interacción ──────────────────────────────────────────────
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: delegateRoot.clicked()
    }
}
