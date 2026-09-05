import qs.Core
import qs.Core.Services
import QtQuick
import Quickshell.Widgets

MouseArea {
    id: root

    property string backgroundColor: Appearance.md3.surface

    implicitWidth: 100
    implicitHeight: 32
    hoverEnabled: true

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.containsMouse ? Qt.tint(root.backgroundColor, Qt.alpha(Appearance.md3.on_surface, 0.08)) : root.backgroundColor

        Behavior on color { ColorAnimation { duration: 200 } }
    }
}