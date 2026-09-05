import qs.Core
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

ProgressBar {
    id: root

    property var barHeight: 8

    property color accentColor: Appearance.md3.primary

    property color backgroundColor: Appearance.md3.surface_container_highest

    width: parent.width

    background: Rectangle {
        implicitWidth:  root.width
        implicitHeight: root.barHeight
        radius:         height / 2
        color:          root.backgroundColor
    }

    // Barra rellena
    contentItem: Item {
        Rectangle {
            width:  root.visualPosition * parent.width
            height: parent.height
            radius: height / 2
            color:  root.accentColor

            Behavior on width {
                NumberAnimation { duration: 150 }
            }
        }
    }   
}