import QtQuick
import "../Core"

Rectangle {
    id: root

    // Propiedades configurables
    property real percentage: 0
    property real barHeight: 10
    property color barColor: Colors.md3.primary
    property color backgroundColor: Colors.md3.surface_variant

    // Definir tamaño implícito para que el padre pueda calcular su tamaño
    implicitHeight: barHeight
    implicitWidth: 180

    color: backgroundColor
    radius: barHeight / 2

    Rectangle {
        id: barForeground
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        height: parent.height
        width: parent.width * Math.min(Math.max(root.percentage, 0), 1)
        color: root.barColor
        radius: parent.radius
        
        Behavior on width {
            NumberAnimation {
                duration: 150
            }
        }
    }
}
