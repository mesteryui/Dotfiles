import QtQuick
import QtQuick.Layouts
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
        color: Appearance.md3.surface
        radius: Appearance.shape.full
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 15
        width: parent.width - 40

        MaterialIcon {
            icon: root.icon
            size: Appearance.font.pixelSize.huge
            color: Appearance.md3.on_surface
            Layout.preferredWidth: 30
            Layout.alignment: Qt.AlignVCenter
        }

        StyledProgressBar {
            id: bar
            from:  0.0
            to:    1.0
            value: root.percentage
            Layout.fillWidth: true 
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: Math.round(root.percentage * 100) + "%"
            font.pixelSize: 16
            color: Appearance.md3.on_surface
            Layout.preferredWidth: 40 
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
