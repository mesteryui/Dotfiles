import qs.Bar.Content
import qs.Core.Services
import qs.Primitives
import QtQuick
import Quickshell

BarItem {
    id: root

    clickable: true
    onClicked: Quickshell.execDetached(["xdg-terminal-exec", "--app-id=local.floating", "-e", "impala"])

    NetworkContent {
        id: content

        anchors.centerIn: parent
    }

    BarToolTip {
        anchorItem: root
        text: (NetworkService.currentNetwork && NetworkService.currentNetwork.name)
              ? NetworkService.currentNetwork.name : "No Network"
        shown: root.hovered
    }
}
