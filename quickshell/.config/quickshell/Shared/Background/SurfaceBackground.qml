// SurfaceBackground.qml
// Fondo de superficie unificado para la shell.
// Fusiona BarBackground y StyledBackground en un único componente reutilizable.
//
// Uso básico:
//   SurfaceBackground { anchors.fill: parent }
//
// Con estado:
//   SurfaceBackground {
//       anchors.fill: parent
//       active:      mouseArea.containsMouse
//       highlighted: mouseArea.pressed
//   }
import QtQuick
import qs.Core

Rectangle {
    id: root

    // ── Estado ─────────────────────────────────────────────────────────────
    /// true cuando el elemento tiene hover o está en foco (tinte suave)
    property bool active: false

    /// true cuando hay un borde de acento (p.ej. ítem seleccionado / MPRIS)
    property bool highlighted: false

    // ── Apariencia ──────────────────────────────────────────────────────────
    /// Color base del fondo. Por defecto usa el token MD3 surface_container_high
    property color baseColor: Appearance.md3.surface_container_high

    /// Radio de esquinas
    property real surfaceRadius: 20

    // ── Computed ─────────────────────────────────────────────────────────────
    radius: surfaceRadius
    color: active
        ? Qt.tint(baseColor, Qt.alpha(Appearance.md3.on_surface, 0.08))
        : baseColor

    border.width: highlighted ? 1 : 0
    border.color: Appearance.md3.primary

    // ── Animaciones ──────────────────────────────────────────────────────────
    Behavior on color {
        ColorAnimation { duration: 150 }
    }
    Behavior on border.width {
        NumberAnimation { duration: 100 }
    }
}
