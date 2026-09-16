import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import M3Shapes

// Tarjeta de historial en estilo Material 3 Expressive: filled card tonal
// sin bordes duros, jerarquía app · hora / titular / cuerpo y contenedor
// de icono con forma expresiva. El elemento bajo el cursor de la lista
// se tiñe con secondary_container y anillo primary para que el foco de
// teclado sea visible.
Rectangle {
    id: root

    required property string summary
    required property string body
    required property string appName
    required property string time
    required property string icon
    required property int index

    signal removeRequested

    readonly property bool current: ListView.isCurrentItem ?? false

    implicitHeight: mainLayout.implicitHeight + 24
    color: root.current ? Appearance.md3.secondary_container : Appearance.md3.surface_container_high
    radius: Appearance.shape.large
    border.width: root.current ? 2 : 0
    border.color: Appearance.md3.primary

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    // State layer de fila completa
    Rectangle {
        id: rowStateLayer

        anchors.fill: parent
        radius: parent.radius
        color: Appearance.md3.on_surface
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
    }

    HoverHandler {
        id: rowHover

        onHoveredChanged: rowStateLayer.opacity = hovered ? 0.06 : 0
    }

    RowLayout {
        id: mainLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        anchors.rightMargin: 32
        spacing: 10

        // Contenedor expresivo para el icono de la app (región cuadrada)
        Item {
            Layout.preferredHeight: 40
            Layout.preferredWidth: 40
            Layout.alignment: Qt.AlignTop
            visible: notificationIcon.source.toString() !== ""

            MaterialShape {
                anchors.fill: parent
                shape: MaterialShape.Cookie4Sided
                color: root.current ? Appearance.md3.secondary : Appearance.md3.primary_container
                animationDuration: 0

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }

            AppIcon {
                id: notificationIcon

                anchors.fill: parent
                anchors.margins: 5
                source: root.icon
            }
        }

        ColumnLayout {
            id: cardContent
            Layout.fillWidth: true

            spacing: 2

            // Fila superior: app · hora
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.appName !== "" || root.time !== ""

                StyledText {
                    visible: root.appName !== ""
                    text: root.appName
                    color: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.sans
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                StyledText {
                    visible: root.time !== ""
                    text: root.time
                    color: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.sans
                    opacity: 0.8
                }
            }

            // Titular
            StyledText {
                Layout.fillWidth: true
                text: root.summary
                color: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                font.bold: true
                font.family: Appearance.font.sans
                font.variableAxes: Appearance.font.variableAxes.title
                font.pixelSize: Appearance.font.pixelSize.normal
                elide: Text.ElideRight
            }
            // Cuerpo
            StyledText {
                text: root.body
                visible: text !== ""
                color: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.font.pixelSize.smallie
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    // Botón (×) para borrar esta notificación individual
    AnimatedIconButton {
        id: closeButton

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        opacity: rowHover.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }

        iconName: "close"

        iconSize: 16

        implicitWidth: 24

        implicitHeight: 24

        iconColor: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant

        baseColor: rowHover.hovered ? Appearance.md3.surface_container_highest : "transparent"

        onClicked: root.removeRequested()
    }
}
