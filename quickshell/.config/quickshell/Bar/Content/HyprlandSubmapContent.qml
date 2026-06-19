import QtQuick
import qs.Components
import qs.Core
Row {
    id: root
    property string text
    spacing: 6

    MaterialIcon {
        icon: "layers"
        size: 16
        color: Colors.md3.on_primary_container
    }

    Text {
        text: root.text
        color: Colors.md3.on_primary_container
        font.pixelSize: 13
        font.weight: Font.Medium
        font.family: "sans-serif"
    }
}