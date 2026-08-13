// ControlToggle — Pill/Tile estilo Material 3 Expressive Quick Settings.
// Soporta vista compacta o vista con estado de 2 líneas (stateText).
import QtQuick
import QtQuick.Layouts
import qs.Core

Rectangle {
    id: root

    property string label:     ""
    property string stateText: ""
    property string iconName:  ""
    property bool   active:    false
    property bool   enable:   true
    signal toggled()

    implicitWidth:  140
    implicitHeight: root.stateText !== "" ? 72 : 48

    radius: Appearance.shape.large
    color: root.active
        ? Appearance.md3.primary_container
        : Appearance.md3.surface_container_high
    opacity: root.enable ? 1.0 : 0.45

    scale: hoverArea.pressed ? 0.96 : (hoverArea.containsMouse ? 1.02 : 1.0)

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on opacity { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // Capa de estado M3 Expressive (Hover & Press overlay)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.active ? Appearance.md3.on_primary_container : Appearance.md3.on_surface
        opacity: hoverArea.pressed ? 0.12 : (hoverArea.containsMouse ? 0.08 : 0.0)
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.stateText !== "" ? 12 : 8
        spacing: 10

        // Contenedor del icono estilo badge M3
        Rectangle {
            id: iconBadge
            Layout.preferredWidth: root.stateText !== "" ? 36 : 32
            Layout.preferredHeight: root.stateText !== "" ? 36 : 32
            radius: height / 2
            color: root.active ? Appearance.md3.primary : Appearance.md3.surface_container_highest
            Behavior on color { ColorAnimation { duration: 150 } }

            MaterialIcon {
                anchors.centerIn: parent
                icon: root.iconName
                size: root.stateText !== "" ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.normal
                color: root.active ? Appearance.md3.on_primary : Appearance.md3.on_surface_variant
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // Textos (Título + Subtítulo opcional)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Layout.alignment: Qt.AlignVCenter

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: root.active ? Font.Medium : Font.Normal
                color: root.active ? Appearance.md3.on_primary_container : Appearance.md3.on_surface
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            StyledText {
                id: stateLabel
                visible: root.stateText !== ""
                Layout.fillWidth: true
                text: root.stateText
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.active ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}

