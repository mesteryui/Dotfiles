import QtQuick
import qs.Core
import qs.Core.Services
import Quickshell.Widgets

MouseArea {
    id: root
    implicitWidth: 100
    implicitHeight: 32
    hoverEnabled: true
    property string backgroundColor: Colors.md3.surface
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.containsMouse ? Qt.tint(root.backgroundColor, Qt.alpha(Colors.md3.on_surface, 0.08)) : backgroundColor
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    
}