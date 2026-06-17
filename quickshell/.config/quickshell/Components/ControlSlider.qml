import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import "../Core"
import ".."

RowLayout {
    id: root

    property string label: ""
    property string iconName: ""
    property real value: 0
    signal moved(real val)

    spacing: 10

    IconImage {
        source: Quickshell.iconPath(root.iconName)
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18
        //color: Colors.md3.on_surface_variant
    }

    Slider {
        Layout.fillWidth: true
        from: 0.0; to: 1.0
        value: root.value
        onMoved: root.moved(value)

        background: Rectangle {
            x: parent.leftPadding
            y: parent.topPadding + parent.availableHeight / 2 - height / 2
            width: parent.availableWidth
            height: 4
            radius: 2
            color: Colors.md3.surface_variant

            Rectangle {
                width: parent.width * parent.parent.visualPosition
                height: parent.height
                radius: parent.radius
                color: Colors.md3.primary
            }
        }

        handle: Rectangle {
            x: parent.leftPadding + parent.visualPosition * parent.availableWidth - width / 2
            y: parent.topPadding + parent.availableHeight / 2 - height / 2
            width: 16; height: 16
            radius: 8
            color: Colors.md3.primary
            border.color: Colors.md3.surface
            border.width: 2
        }
    }
}