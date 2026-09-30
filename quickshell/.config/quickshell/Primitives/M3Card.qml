// M3Card — Material 3 Expressive Container Card.
import qs.Core
import QtQuick
import QtQuick.Effects

Item {
    id: root

    default property alias content: _inner.data

    // Spec M3 cards: radio 12dp.
    property int radius: Appearance.shape.small
    property color color: Appearance.md3.surface_container_high
    property int padding: 0
    property bool clickable: false
    property bool shadowEnabled: true

    // Referencia al único hijo de contenido real (el Layout/Item que se
    // pasa vía "content"). Se asume un único hijo raíz, como se usa en
    // todo el proyecto (SectionCard pasa un ColumnLayout).
    readonly property Item _content: _inner.children.length > 0 ? _inner.children[0] : null

    signal clicked

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

    Rectangle {
        id: _bg

        anchors.fill: parent
        radius: root.radius
        color: root.color

        Behavior on color {
            ColorAnimation {
                duration: Appearance.motion.short3
            }
        }
    }

    // Sombra tonal M3 (gateada: sin pass offscreen si está desactivada).
    // source se asigna en onCompleted para evitar warning
    // "ShaderEffect: 'source' does not have a matching property" del primer frame.
    MultiEffect {
        id: cardShadow
        anchors.fill: _bg
        visible: root.shadowEnabled
        shadowEnabled: root.shadowEnabled
        shadowColor: Appearance.md3.shadow
        shadowOpacity: Appearance.elevation1.opacity
        shadowBlur: Appearance.elevation1.blur
        shadowVerticalOffset: Appearance.elevation1.offsetY
        shadowHorizontalOffset: 0
        z: -1
        Component.onCompleted: cardShadow.source = _bg
    }

    // Capa de estado para cards clicables
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.clickable
        color: Appearance.md3.on_surface
        opacity: cardArea.pressed ? Appearance.state.pressed : (cardArea.containsMouse ? Appearance.state.hovered : 0.0)

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.motion.short2
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
