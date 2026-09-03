import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Primitives

Rectangle {
    id: root

    required property string summary
    required property string body
    required property string appName
    required property string time
    required property string icon
    required property int index

    signal removeRequested

    implicitHeight: mainLayout.implicitHeight + 20
    color: Appearance.md3.surface_container_high
    radius: Appearance.shape.large
    border.width: 1
    border.color: Qt.alpha(Appearance.md3.outline_variant, 0.45)

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

        // Fondo tonal para el icono de la app
        Item {
            Layout.preferredHeight: 36
            Layout.preferredWidth: 36
            Layout.alignment: Qt.AlignTop
            visible: notificationIcon.source.toString() !== ""

            Rectangle {
                anchors.fill: parent
                radius: Appearance.shape.small
                color: Appearance.md3.primary_container
            }

            AppIcon {
                id: notificationIcon
                anchors.fill: parent
                anchors.margins: 4
                source: root.icon
            }
        }

        ColumnLayout {
            id: cardContent
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: root.summary
                    color: Appearance.md3.on_surface
                    font.bold: true
                    font.family: Appearance.font.sans
                    font.pixelSize: Appearance.font.pixelSize.normal
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                StyledText {
                    text: root.time
                    color: Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.sans
                }
            }
            StyledText {
                text: root.body
                visible: text !== ""
                color: Appearance.md3.on_surface_variant
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.font.pixelSize.smallie
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            StyledText {
                visible: root.appName !== ""
                text: root.appName
                color: Appearance.md3.on_surface_variant
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.sans
                opacity: 0.8
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
        iconColor: Appearance.md3.on_surface_variant
        baseColor: "transparent"
        onClicked: root.removeRequested()
    }
}
