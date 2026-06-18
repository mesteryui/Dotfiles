import QtQuick
import qs.Core

Item {
    id: root
    property real  value:       0.0   // 0–1
    property color accentColor: Colors.md3.primary
    
    implicitWidth: 200
    implicitHeight: 6

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color:  Colors.md3.surface_container   // track
    }

    Rectangle {
        id: bar
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: {
            if (root.value <= 0) return 0;
            const targetWidth = root.width * Math.min(1, root.value);
            // Ensure we at least show a circle if there is some value, but don't exceed root.width
            return Math.min(root.width, Math.max(root.height, targetWidth));
        }
        radius: height / 2
        color:  root.accentColor

        Behavior on width {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }
}
