pragma ComponentBehavior: Bound

import qs.Core
import QtQuick

// BarItem — contrato base de los módulos de barra.
// Raíz: píldora de 30dp sobre surface_container_high (radio shape.normal).
// Contenido: hijo por defecto, centrado; el ancho implícito sale del hijo
// más el padding horizontal. La altura es fija (30).
// Interacción: clickable habilita el área y el cursor; clicked(mouse) al pulsar.
// `area` expone el MouseArea para casos especiales; hovered/pressed son los
// atajos de lectura (equivalen a area.containsMouse / area.pressed).
Rectangle {
    id: root

    property int horizontalPadding: 12
    property int verticalPadding: 6
    property color backgroundColor: Appearance.md3.surface_container_high
    property int itemRadius: Appearance.shape.normal
    property bool clickable: false
    property alias area: mouseArea
    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool pressed: mouseArea.pressed
    default property alias data: contentLoader.data

    signal clicked(variant mouse)

    implicitWidth: contentLoader.childrenRect.width + (root.horizontalPadding * 2)

    implicitHeight: 30

    radius: root.itemRadius
    color: root.clickable && root.hovered ? Qt.tint(root.backgroundColor, Qt.alpha(Appearance.md3.on_surface,
                                                                                   0.08)) : root.backgroundColor

    Behavior on color {
        ColorAnimation {
            duration: Appearance.motion.short3
        }
    }

    Item {
        id: contentLoader

        anchors.centerIn: parent
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => root.clicked(mouse)
    }
}
