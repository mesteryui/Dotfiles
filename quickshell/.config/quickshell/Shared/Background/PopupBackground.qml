import qs.Core
import QtQuick

Rectangle {
    id: root

    // ── Apariencia ──────────────────────────────────────────
    property color baseColor: Appearance.md3.surface
    property real  surfaceRadius: 20
    property bool  showBorder: true

    // ── Internos ────────────────────────────────────────────
    radius: surfaceRadius
    color:  baseColor
    clip:   true          // necesario para que las secciones internas respeten el radius

    // Borde encima de todo el contenido clippeado
    Rectangle {
        anchors.fill: parent
        radius:       parent.radius
        color:        "transparent"
        border.color: Appearance.md3.outline_variant
        border.width: root.showBorder ? 1 : 0
        z:            10
    }
}