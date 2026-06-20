import Quickshell
import Quickshell.Widgets
import QtQuick
import qs.Bar.Content

BarItem {
    id: root
    
    clickable: true
    onClicked: Quickshell.execDetached([
        "xdg-terminal-exec", 
        "--app-id=local.floating", 
        "-e", 
        "impala"
    ])

    NetworkContent {
        id: content
        anchors.centerIn: parent
    }
}
