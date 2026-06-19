import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.Core.Services
import qs.Core
import qs.Components

BarItem {
    id: root
    
    clickable: true
    onClicked: Quickshell.execDetached([
        "xdg-terminal-exec", 
        "--app-id=local.floating", 
        "-e", 
        "impala"
    ])

    MaterialIcon {
        id: networkIcon
        anchors.centerIn: parent
        size: 20
        color: Colors.md3.on_surface
        icon: NetworkService.materialIconBySignal
    }
}
