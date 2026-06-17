import QtQuick
import QtQuick.Effects
import "../Core" 

Item {
    id: root
    default property alias content: _inner.data
    
    // Asumimos que los tokens se definen en el componente padre o se ajustan aquí
    readonly property int _radius: 16

    implicitHeight: _inner.childrenRect.height + 0

    // Sombra tonal (elevation 1)
    MultiEffect {
        anchors.fill: _bg
        source:       _bg
        shadowEnabled:    true
        shadowColor:      Colors.md3.shadow
        shadowOpacity:    0.08
        shadowBlur:       0.4
        shadowVerticalOffset:   2
        shadowHorizontalOffset: 0
    }

    Rectangle {
        id: _bg
        anchors.fill: parent
        radius: root._radius
        color:  Colors.md3.surface_container_high
    }

    Item {
        id: _inner
        anchors.fill: parent
    }
}
