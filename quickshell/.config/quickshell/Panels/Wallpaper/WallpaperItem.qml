pragma ComponentBehavior: Bound

import qs.Panels.Wallpaper.Content
import qs.Core
import QtQuick

Item {
    id: delegateRoot

    required property int index
    required property string filePath

    signal clicked

    property int surfaceRadius: 18

    readonly property bool isSelected: ListView.isCurrentItem
    readonly property int distance: Math.abs(ListView.view.currentIndex - index)
    readonly property real side: index < ListView.view.currentIndex ? -1 :
                                index > ListView.view.currentIndex ? 1 : 0

    // Ancho dinámico del delegado: seleccionada se expande a 560px, laterales 200px.
    // Altura aumentada a 310px para que las imágenes se vean más altas y prominentes.
    implicitWidth: isSelected ? 560 : 200
    implicitHeight: 310

    // Orden de apilado en ListView: el delegado seleccionado se sitúa siempre al frente (z: 100)
    // para evitar que los delegados vecinos (con opacidad reducida y espaciado negativo)
    // se superpongan u obstruyan la tarjeta seleccionada.
    z: isSelected ? 100 : (50 - distance)

    Behavior on implicitWidth {
        SpringAnimation {
            spring: 2.8
            damping: 0.20
            mass: 0.7
            epsilon: 0.5
        }
    }

    Item {
        id: cardContainer

        anchors.fill: parent

        // Escala y opacidad según distancia al elemento seleccionado
        scale: delegateRoot.isSelected ? 1.0 : Math.max(0.74, 0.88 - delegateRoot.distance * 0.05)
        opacity: delegateRoot.isSelected ? 1.0 : Math.max(0.20, 0.65 - delegateRoot.distance * 0.18)

        // Inclinación diagonal oblicua (Shear en X de -0.28)
        transform: [
            Matrix4x4 {
                matrix: Qt.matrix4x4(
                    1, -0.28, 0, 0,
                    0,  1.0,  0, 0,
                    0,  0.0,  1, 0,
                    0,  0.0,  0, 1
                )
            }
        ]

        Behavior on scale {
            SpringAnimation {
                spring: 2.6
                damping: 0.20
                mass: 0.7
                epsilon: 0.003
            }
        }

        Behavior on opacity {
            SpringAnimation {
                spring: 2.8
                damping: 0.28
                mass: 0.8
                epsilon: 0.01
            }
        }

        // Resplandor y sombra exterior: resalta con el color primario de Matugen
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: delegateRoot.surfaceRadius + 4
            color: delegateRoot.isSelected ? Qt.alpha(Appearance.md3.primary, 0.22) :
                                             Qt.rgba(0, 0, 0, 0.25)
            z: -1

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.motion.normal
                }
            }
        }

        // Contenido visual de la tarjeta
        WallpaperItemContent {
            anchors.fill: parent
            isSelected: delegateRoot.isSelected
            hovered: mouse.containsMouse
            radius: delegateRoot.surfaceRadius
            filePath: delegateRoot.filePath
            delegateIndex: delegateRoot.index
            listCurrentIndex: ListView.view ? ListView.view.currentIndex : -1
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: false
        onClicked: {
            if (ListView.view && ListView.view.moving)
                return;
            delegateRoot.clicked();
        }
    }
}
