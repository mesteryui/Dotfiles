import QtQuick
import "@Core/Colors.qml" as Colors

Item {
    id: root
    property real  value:       0.0   // 0–1
    property color accentColor: Colors.md3.primary
    implicitHeight: 6

    Rectangle {
        anchors.fill: parent
        radius: 3
        color:  Colors.md3.surface_container   // track
    }

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width:  Math.max(radius * 2, root.width * Math.min(1, Math.max(0, root.value)))
        radius: 3
        color:  root.accentColor

        Behavior on width {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }
}
