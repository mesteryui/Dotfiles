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
import qs.Core
import QtQuick

Rectangle {
    id: root

    // ── Estado ─────────────────────────────────────────────────────────────
    /// true cuando el elemento tiene hover o está en foco (tinte suave)
    property bool active: false

    /// true cuando hay un borde de acento (p.ej. ítem seleccionado / MPRIS)
    property bool highlighted: false

    /// Trazo hairline de reposo (superficies flotantes: barra, paneles).
    /// Los elementos internos de la barra lo dejan en false.
    property bool bordered: false

    // ── Apariencia ──────────────────────────────────────────────────────────
    /// Color base del fondo. Por defecto usa el token MD3 surface_container_high
    property color baseColor: Appearance.md3.surface_container_high

    /// Radio de esquinas
    property real surfaceRadius: Appearance.shape.card

    // ── Computed ─────────────────────────────────────────────────────────────
    radius: surfaceRadius
    color: active ? Qt.tint(baseColor, Qt.alpha(Appearance.md3.on_surface, 0.08)) : baseColor

    border.width: (bordered || highlighted) ? Appearance.border.width : 0
    border.color: highlighted ? Appearance.border.focus : Appearance.border.subtleOn(color)

    // ── Animaciones ──────────────────────────────────────────────────────────
    Behavior on color {
        ColorAnimation {
            duration: Appearance.motion.fast
        }
    }
    Behavior on border.width {
        NumberAnimation {
            duration: Appearance.motion.veryFast
        }
    }
}
