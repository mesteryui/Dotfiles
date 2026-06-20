import QtQuick
import QtQuick.Layouts
import qs.Primitives
import qs.Core

Item {
    id: root
    implicitHeight: 100

    Text {
        anchors.centerIn: parent
        text: "Weather content placeholder"
        color: Colors.md3.on_surface_variant
        font.pixelSize: 14
    }
}
