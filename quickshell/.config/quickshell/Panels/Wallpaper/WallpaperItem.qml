pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.Panels.Wallpaper.Content
import qs.Core
import qs.Shared.Background

Item {
    id: delegateRoot

    property var modelData
    property int surfaceRadius: 16         // fuente única de verdad para el radio

    readonly property bool isSelected: ListView.isCurrentItem

    implicitWidth: 280
    implicitHeight: 200

    scale: isSelected ? 1.05 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
    }

    // ── Background ────────────────────────────────────────────
    SurfaceBackground {
        id: background
        anchors.fill: parent               // ← faltaba esto
        radius: delegateRoot.surfaceRadius
        color: delegateRoot.isSelected
            ? Appearance.md3.surface_container_highest
            : Appearance.md3.surface_container_low
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowBlur: delegateRoot.isSelected ? 0.8 : 0.4
        shadowVerticalOffset: delegateRoot.isSelected ? 4 : 2
        shadowHorizontalOffset: 0
        blurMax: 16
        shadowOpacity: delegateRoot.isSelected ? 0.25 : 0.08

        Behavior on shadowOpacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        Behavior on shadowVerticalOffset {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    // ── Content ───────────────────────────────────────────────
    WallpaperItemContent {
        anchors.fill: parent
        isSelected: delegateRoot.isSelected
        hovered: mouse.containsMouse      // ← bool, no el MouseArea entero
        radius: delegateRoot.surfaceRadius // ← mismo radio que el Background
    }

    // ── Interacción ───────────────────────────────────────────
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
    }
}
