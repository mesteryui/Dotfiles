import qs.Core
import QtQuick

Rectangle {
    id: root

    // ── Apariencia ──────────────────────────────────────────
    property color baseColor: Appearance.md3.surface
    property real surfaceRadius: Appearance.shape.card
    property bool showBorder: true

    // ── Internos ────────────────────────────────────────────
    radius: surfaceRadius
    color: baseColor
    clip: true          // necesario para que las secciones internas respeten el radius

    // Fundido suave al cambiar de tema (matugen): evita el corte duro
    // de colors.json. La primera carga funde desde transparente.
    Behavior on color {
        ColorAnimation {
            duration: Appearance.motion.fast
        }
    }

    // Sin `layer.enabled`: las sombras MultiEffect que leían esta textura
    // como source ya no existen en ningún consumidor. Mantener la capa
    // obligaba a renderizar cada popup a un FBO de su tamaño (y a
    // re-renderizarlo en cada cambio interno) sin que nadie leyera esa
    // textura.

    // Borde encima de todo el contenido clippeado
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: Appearance.border.subtleOn(root.baseColor)
        border.width: root.showBorder ? Appearance.border.width : 0
        z: 10
    }
}
