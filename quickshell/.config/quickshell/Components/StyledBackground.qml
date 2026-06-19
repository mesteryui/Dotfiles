import Quickshell
import QtQuick
import qs.Core

Rectangle {
    id: root
    property alias content: contentLoader.sourceComponent
    color: Colors.md3.surface_container_high
    radius: 20
    Item {
        id: contentLoader
        anchors.centerIn: parent
    }
}