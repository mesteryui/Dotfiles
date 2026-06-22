import QtQuick
import qs.Core

ApplicationWindow {
    id: window
    visible: false

    Rectangle {
        anchors.fill: parent
        color: Colors.md3.background
    }

    Item {
        anchors.fill: parent
        Row {
            id: row
        }
    }

}