import qs.Bar.Content
import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Controls

BarItem {
    id: root

    clickable: true
    backgroundColor: Services.IdleInhibitedService.inhibited ? Appearance.md3.primary_container : Appearance.md3.surface_container_high

    onClicked: Services.IdleInhibitedService.toggle()

    CaffeineContent {
        anchors.centerIn: parent
    }

    ToolTip {
        id: tooltip

        // Debajo del icono, centrado; si la barra está abajo, encima.
        readonly property bool barAtBottom: Services.ConfigService.configs.bar.position === "bottom"
        x: (parent.width - width) / 2
        y: barAtBottom ? -height - 8 : parent.height + 8
        text: Services.IdleInhibitedService.inhibited ? "Cafeína activada (suspensión inhibida)" : "Cafeína desactivada"
        visible: root.area.containsMouse
        delay: 500
        timeout: 5000

        contentItem: StyledText {
            text: tooltip.text
            color: Appearance.md3.inverse_on_surface
            font.pixelSize: 12
            wrapMode: Text.NoWrap
        }

        background: Rectangle {
            color: Appearance.md3.inverse_surface
            radius: Appearance.shape.extraSmall
        }

        padding: 8
        horizontalPadding: 12
    }
}
