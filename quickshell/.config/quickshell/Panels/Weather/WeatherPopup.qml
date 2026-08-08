import Quickshell
import qs.Shared.Background
import QtQuick
import qs.Core
import Quickshell.Hyprland
PopupWindow {
    id: root
    color: "transparent"
    grabFocus: true
    implicitWidth: content.implicitWidth + 20
    implicitHeight: content.implicitHeight + 10

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => root.visible = false)
    }

    SurfaceBackground {
        //color: Appearance.md3.surface
        anchors.fill: parent
    }
    WeatherPopupContent {
        id: content
        anchors.fill: parent
    }
}