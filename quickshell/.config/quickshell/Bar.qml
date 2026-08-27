import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Bar
import qs.Core
import qs.Core.Services as Services

PanelWindow {
    id: root

    readonly property bool isTop: Services.ConfigService.configs.bar.position == "top" || Services.ConfigService.configs.bar.position == ""

    property int barHeight: Services.ConfigService.configs.bar.height

    // Configuramos cuánto queremos que mida la lágrima
    property real teardropLength: 30
    property real teardropWidth: 35

    WlrLayershell.layer: WlrLayer.Top
    // La zona exclusiva sigue siendo SOLO el alto de la barra (no molesta a otras apps)
    WlrLayershell.exclusiveZone: barHeight
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.namespace: "quickshell:bar"

    anchors {
        top: root.isTop
        bottom: !root.isTop
        right: true
        left: true
    }

    implicitWidth: content.width

    // ¡CLAVE! Damos espacio físico extra en la ventana para dibujar la lágrima sin que se recorte.
    implicitHeight: barHeight + teardropLength

    color: "transparent"

    // 1. Fondo de la Barra
    BarBackground {
        id: bg
        anchors.left: parent.left
        anchors.right: parent.right
        // Lo anclamos según si está arriba o abajo
        y: root.isTop ? 0 : root.teardropLength
        height: root.barHeight
        color: Appearance.md3.surface
        radius: 0
    }

    // 3. Contenido de la barra
    MainBar {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        y: root.isTop ? 0 : root.teardropLength
        height: root.barHeight
    }
}
