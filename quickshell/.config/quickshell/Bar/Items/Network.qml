import Quickshell
import QtQuick
import qs.Bar.Content
import QtQuick.Controls
import qs.Core
import qs.Core.Services
import qs.Primitives

BarItem {
    id: root

    clickable: true
    onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "impala"])

    NetworkContent {
        id: content
        anchors.centerIn: parent
    }

    ToolTip {
        id: tooltip
        text: NetworkService.currentNetwork.name ?? "No Network"
        visible: root.area.containsMouse
        delay: 500      // ms antes de mostrarse
        timeout: 5000   // ms antes de ocultarse solo

        contentItem: StyledText {
            text: tooltip.text
            color: Appearance.md3.on_surface
            font.pixelSize: 12
            wrapMode: Text.NoWrap
        }

        background: Rectangle {
            color: Appearance.md3.surface
            radius: Appearance.shape.normal
        }

        padding: 8
        horizontalPadding: 12
    }
}
