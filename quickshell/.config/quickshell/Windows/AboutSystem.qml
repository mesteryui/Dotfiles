import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.Core

FloatingWindow {
    id: window
    visible: false
    color: "transparent"
    width: 600
    height: 400

    Rectangle {
        anchors.fill: parent
        color: Appearance.md3.background
    }

    Item {
        anchors.fill: parent
        RowLayout {
            id: row
            Image {

            }
        }
    }

}