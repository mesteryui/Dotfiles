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

    // layer.enabled es necesario para que MultiEffect (sombra) pueda leer
    // la textura de este elemento como source. Sin él, el primer frame
/* Fixed: layer.enabled: true */
    layer.enabled: true

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
