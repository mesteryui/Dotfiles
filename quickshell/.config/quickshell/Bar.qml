import qs.Bar
import qs.Core
import qs.Core.Services as Services
import qs.Shared.Background
import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    model: Quickshell.screens
    delegate: Scope {
        id: delegateScope

        required property ShellScreen modelData
        // qmllint disable uncreatable-type

        PanelWindow {
            id: root
            // qmllint enable uncreatable-type

            screen: delegateScope.modelData

            readonly property var barType: Services.GameMode.enabled ? "no_floating" : Services.ConfigService.configs.bar.barType

            readonly property bool isFloating: barType === "floating"

            readonly property bool isTop: Services.ConfigService.configs.bar.position == "top" || Services.ConfigService.configs.bar.position == ""

            property int barHeight: Services.ConfigService.configs.bar.height

            // Espacio físico extra solo en flotante para dibujar la
            // lágrima sin que se recorte. Sin flotar no se reserva nada.
            property real teardropLength: 30

            // Margen exterior en modo flotante / laterales del contenido.
            readonly property int floatingMargin: 3
            readonly property int contentMargin: 6

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
            margins {
                top: root.isFloating ? root.floatingMargin : 0
                bottom: root.isFloating ? root.floatingMargin : 0
                left: root.isFloating ? root.floatingMargin : 0
                right: root.isFloating ? root.floatingMargin : 0
            }

            // Sin implicitWidth: la ventana ya ocupa todo el ancho por los
            // anchors left/right (antes `content.width` cerraba un binding loop
            // con MainBar, anclado a su vez al padre).
            // ¡CLAVE! Espacio físico extra solo en flotante para dibujar la
            // lágrima sin que se recorte. Sin flotar no se reserva nada.
            implicitHeight: barHeight + (root.isFloating ? teardropLength : 0)

            color: "transparent"

            // 1. Fondo de la Barra
            SurfaceBackground {
                id: bg

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: root.isTop ? parent.top : undefined
                anchors.bottom: !root.isTop ? parent.bottom : undefined
                height: root.barHeight
                color: Appearance.md3.surface
                radius: root.isFloating ? Appearance.shape.full : 0
            }

            // 3. Contenido de la barra
            MainBar {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.contentMargin
                anchors.rightMargin: root.contentMargin
                anchors.top: root.isTop ? parent.top : undefined
                anchors.bottom: !root.isTop ? parent.bottom : undefined
                height: root.barHeight
            }
        }
    }
}
