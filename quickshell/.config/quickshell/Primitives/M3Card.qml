// M3Card — Material 3 Expressive Container Card.
import QtQuick
import QtQuick.Effects
import qs.Core

Item {
    id: root
    default property alias content: _inner.data
    
    property int radius: Appearance.shape.large
    property color color: Appearance.md3.surface_container_high
    property int padding: 0
    property bool clickable: false
    property bool shadowEnabled: true
    signal clicked()

    // Dimensiones naturales basadas en el contenido
    implicitWidth: _inner.childrenRect.x + _inner.childrenRect.width + (padding * 2)
    implicitHeight: _inner.childrenRect.y + _inner.childrenRect.height + (padding * 2)

    scale: root.clickable ? (cardArea.pressed ? 0.98 : (cardArea.containsMouse ? 1.015 : 1.0)) : 1.0
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // Sombra tonal M3
    MultiEffect {
        anchors.fill: _bg
        source:       _bg
        shadowEnabled:    root.shadowEnabled
        shadowColor:      Appearance.md3.shadow
        shadowOpacity:    0.08
        shadowBlur:       0.4
        shadowVerticalOffset:   2
        shadowHorizontalOffset: 0
    }

    Rectangle {
        id: _bg
        anchors.fill: parent
        radius: root.radius
        color:  root.color
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // Capa de estado para cards clicables
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.clickable
        color: Appearance.md3.on_surface
        opacity: cardArea.pressed ? 0.12 : (cardArea.containsMouse ? 0.08 : 0.0)
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    Item {
        id: _inner
        x: root.padding
        y: root.padding
        width: root.width - (root.padding * 2)
        height: root.height - (root.padding * 2)
    }

    MouseArea {
        id: cardArea
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}

