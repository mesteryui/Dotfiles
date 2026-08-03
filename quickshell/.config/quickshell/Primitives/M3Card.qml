import QtQuick
import QtQuick.Effects
import qs.Core

Item {
    id: root
    default property alias content: _inner.data
    
    readonly property int _radius: 16
    property int padding: 0

    // Dimensiones naturales basadas en el contenido
    implicitWidth: _inner.childrenRect.x + _inner.childrenRect.width + padding
    implicitHeight: _inner.childrenRect.y + _inner.childrenRect.height + padding

    // Sombra tonal (elevation 1)
    MultiEffect {
        anchors.fill: _bg
        source:       _bg
        shadowEnabled:    true
        shadowColor:      Appearance.md3.shadow
        shadowOpacity:    0.08
        shadowBlur:       0.4
        shadowVerticalOffset:   2
        shadowHorizontalOffset: 0
    }

    Rectangle {
        id: _bg
        anchors.fill: parent
        radius: root._radius
        color:  Appearance.md3.surface_container_high
    }

    Item {
        id: _inner
        x: root.padding
        y: root.padding
        // El contenedor interno no se ancla para que childrenRect sea útil
        // pero permitimos que los hijos crezcan si el padre (root) es estirado
        width: root.width - (root.padding * 2)
        height: root.height - (root.padding * 2)
    }
}
