pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.Panels.Wallpaper.Content
import qs.Core
import qs.Shared.Background

Item {
    id: delegateRoot
    
    // 1. CONVENCIÓN QUICKSHELL + QT6: 'required' bloquea la inicialización
    // hasta que el modelo inyecte los datos reales aquí.
    required property var modelData

    property int surfaceRadius: 16

    readonly property bool isSelected: ListView.isCurrentItem

    implicitWidth: 300
    implicitHeight: 200

    scale: isSelected ? 1.02 : 1.0
    //scale: 1.0
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

    MultiEffect {
        source: background
        anchors.fill: background
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowBlur: delegateRoot.isSelected ? 0.8 : 0.4
        shadowVerticalOffset: delegateRoot.isSelected ? 4 : 2
        shadowOpacity: delegateRoot.isSelected ? 0.25 : 0.08
        blurMax: 16
        Behavior on shadowOpacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on shadowVerticalOffset { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }


    // ── Content ───────────────────────────────────────────────
    WallpaperItemContent {
        anchors.fill: parent
        isSelected: delegateRoot.isSelected
        hovered: mouse.containsMouse      // ← bool, no el MouseArea entero
        radius: delegateRoot.surfaceRadius // ← mismo radio que el Background
        filePath: delegateRoot.modelData?.filePath ?? ""
        
    }

    // ── Interacción ───────────────────────────────────────────
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
    }
}
