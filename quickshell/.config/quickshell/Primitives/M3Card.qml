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
    signal clicked

    // Referencia al único hijo de contenido real (el Layout/Item que se
    // pasa vía "content"). Se asume un único hijo raíz, como se usa en
    // todo el proyecto (SectionCard pasa un ColumnLayout).
    readonly property Item _content: _inner.children.length > 0 ? _inner.children[0] : null

    // Dimensiones naturales basadas en el implicitWidth/implicitHeight
    // REAL del contenido, no en childrenRect (que depende de que el
    // contenido ya esté posicionado/dimensionado y provoca timing raro
    // en el primer layout pass, dejando tarjetas con altura 0 o mal
    // calculada la primera vez que se muestra una pestaña).
    implicitWidth: (root._content ? root._content.implicitWidth : 0) + (padding * 2)
    implicitHeight: (root._content ? root._content.implicitHeight : 0) + (padding * 2)

    scale: root.clickable ? (cardArea.pressed ? 0.98 : (cardArea.containsMouse ? 1.015 : 1.0)) : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    // Sombra tonal M3
    MultiEffect {
        anchors.fill: _bg
        source: _bg
        shadowEnabled: root.shadowEnabled
        shadowColor: Appearance.md3.shadow
        shadowOpacity: 0.08
        shadowBlur: 0.4
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
    }

    Rectangle {
        id: _bg
        anchors.fill: parent
        radius: root.radius
        color: root.color
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    // Capa de estado para cards clicables
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.clickable
        color: Appearance.md3.on_surface
        opacity: cardArea.pressed ? 0.12 : (cardArea.containsMouse ? 0.08 : 0.0)
        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
    }

    Item {
        id: _inner
        x: root.padding
        y: root.padding
        width: root.width - (root.padding * 2)
        height: root.height - (root.padding * 2)
    }

    // Propaga automáticamente el ancho disponible al contenido real.
    // Esto elimina la necesidad de que cada componente que usa M3Card
    // tenga que replicar a mano "width: card.width > 0 ? ... : 400"
    // (que es justamente la causa de que el contenido no se viera bien
    // en el primer render de cada pestaña).
    Binding {
        target: root._content
        property: "width"
        value: _inner.width
        when: root._content !== null
        restoreMode: Binding.RestoreBindingOrValue
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
