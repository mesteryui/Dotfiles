import QtQuick
import QtQuick.Layouts
import qs.Core

Rectangle {
    id: root

    required property string summary
    required property string body
    required property string appName
    required property string time
    required property int index

    signal removeRequested()

    implicitHeight: cardContent.implicitHeight + 16
    color: Appearance.md3.surface_variant
    radius: 6

    ColumnLayout {
        id: cardContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        anchors.rightMargin: 20
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.summary
                color: Appearance.md3.on_surface_variant
                font.bold: true
                font.family: Appearance.font.sans
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: root.time
                color: Appearance.md3.on_surface_variant
                font.pixelSize: 11
                font.family: Appearance.font.sans
            }
        }
        Text {
            text: root.body
            visible: text !== ""
            color: Appearance.md3.on_surface_variant
            font.family: Appearance.font.sans
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Text {
            visible: root.appName !== ""
            text: root.appName
            color: Appearance.md3.on_surface_variant
            font.pixelSize: 10
            font.family: Appearance.font.sans
        }
    }

    // Botón (×) para borrar esta notificación individual
    Text {
        text: "×"
        color: "#f7768e"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 5

        MouseArea {
            anchors.fill: parent
            onClicked: root.removeRequested()
        }
    }
}
