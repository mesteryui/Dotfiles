import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../"
import "../Services" as Services
Rectangle {
    id: root
    required property var modelData
    required property bool isActive
    
    width: isActive ? 40 : 30   // se expande al activarse
    height: 30
    radius: 30
    color: isActive ? Colors.primary : Colors.secondary_container

    Behavior on color {
        ColorAnimation { duration: 200 }
    }
    Behavior on width {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    scale: mouseArea.pressed ? 0.85 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }
    Text {
        font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
        anchors.centerIn: parent
        text: root.modelData.id
        color: root.isActive ? Colors.on_primary : Colors.on_surface
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + root.modelData.id + '"})')
    }
}
