// ControlToggle — Pill horizontal estilo Material You / GNOME Quick Settings.
// Activo:   primary_container + texto on_primary_container
// Inactivo: surface_container_high + texto on_surface_variant
import QtQuick
import qs.Core

Rectangle {
    id: root

    property string label:    ""
    property string iconName: ""
    property bool   active:   false
    signal toggled()

    implicitWidth:  120
    implicitHeight: 48

    radius: Appearance.shape.large
    color: root.active
        ? Appearance.md3.primary_container
        : (hoverArea.containsMouse
            ? Qt.tint(Appearance.md3.surface_container_high, Qt.rgba(0,0,0,0.05))
            : Appearance.md3.surface_container_high)

    Behavior on color { ColorAnimation { duration: 150 } }

    Row {
        anchors.centerIn: parent
        spacing: 8

        MaterialIcon {
            id: chip_icon
            anchors.verticalCenter: parent.verticalCenter
            icon: root.iconName
            size: Appearance.font.pixelSize.large
            color: root.active
                ? Appearance.md3.on_primary_container
                : Appearance.md3.on_surface_variant
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            id: chip_label
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: root.active ? Font.Medium : Font.Normal
            color: root.active
                ? Appearance.md3.on_primary_container
                : Appearance.md3.on_surface_variant
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
