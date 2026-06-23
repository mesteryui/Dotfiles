import QtQuick
import qs.Primitives
import qs.Core
Item {
    id: root
    property string text
    implicitHeight: 30
    implicitWidth: layout.childrenRect.width
    Row {
        id: layout
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        MaterialIcon {
            icon: "layers"
            size: 16
            color: Colors.md3.on_primary_container
        }

        StyledText {
            text: root.text
            color: Colors.md3.on_primary_container
            font.pixelSize: 14
        }
    }
}