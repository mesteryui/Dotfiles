import QtQuick
import qs.Core
import qs.Primitives
import qs.Shared.Background

BaseOSD {
    id: root

    required property real percentage
    required property string icon

    implicitWidth: 320
    implicitHeight: 60

    PopupBackground {
        anchors.fill: parent
        color: Colors.md3.surface
        radius: height / 2
    }

    Row {
        anchors.centerIn: parent
        spacing: 15
        width: parent.width - 40

        MaterialIcon {
            icon: root.icon
            anchors.verticalCenter: parent.verticalCenter
            size: 24
            color: Colors.md3.on_surface
            width: 30
        }

        StyledProgressBar {
            id: bar
            from:  0.0
            to:    1.0
            value: root.percentage
            width: 180
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: Math.round(root.percentage * 100) + "%"
            font.pixelSize: 16
            color: Colors.md3.on_surface
            width: 40
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
