pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.Core.Services as Services
import qs.Panels.Controls
import qs.Shared.Background
import qs.Primitives
import qs.Core

Item {
    id: root
    implicitWidth: content.childrenRect.width + 49
    implicitHeight: 30
    LazyLoader {
        id: popupLoader
        loading: interaction.pressed || interaction.hoveredChanged
        PanelWithControls {
            id: popup
        }
    }
    MouseArea {
        id: interaction
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const w = popupLoader.item
            if (w) w.visible = !w.visible
        }
        enabled: true
    }

    SurfaceBackground {
        id: background
        anchors.fill: parent
        active: interaction.containsMouse
        scale: interaction.pressed ? 0.92: (interaction.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
    }

    MaterialIcon {
        id: content
        icon: "rocket_launch"
        size: Appearance.font.pixelSize.larger
        color: Appearance.md3.on_surface
        anchors.centerIn: parent
    }

}
