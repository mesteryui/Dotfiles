import qs.Core // Para acceder a tu sistema de colores
import QtQuick
Rectangle {
    id: root
    
    // Propiedades personalizables desde el Wrapper
    property bool active: false
    property bool highlighted: false
    property color baseColor: Colors.md3.surface_container_high
    property real surfaceRadius: 20

    // Estética base
    radius: surfaceRadius
    color: active ? Qt.tint(baseColor, Qt.alpha(Colors.md3.on_surface, 0.08)) : baseColor
    
    // Lógica de borde (como la que querías en MPRIS)
    border.width: highlighted ? 1 : 0
    border.color: Colors.md3.primary

    // Animaciones fluidas unificadas
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.width { NumberAnimation { duration: 100 } }
}
