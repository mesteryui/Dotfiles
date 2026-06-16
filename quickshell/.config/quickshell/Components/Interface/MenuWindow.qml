import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../Core"
import "../../Core/Services" as Services
import "."
PanelWindow {
    id: root
    
    property string menuTitle: ""
    property alias content: contentContainer.data
    default property alias data: contentContainer.data
    
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible) {
                root.visible = false;
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.visible) {
                root.visible = false;
            }
        }
    }

    Rectangle {
        id: menuRect
        anchors.fill: parent
        color: Colors.surface
        radius: 20
        layer.enabled: true
        
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutBack
            }
        }

        // Borde
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Colors.outline_variant
            radius: parent.radius
            z: 10
        }

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: root.menuTitle
                visible: text !== ""
                font.family: Services.ConfigService?.getConfig("fontSans") ?? "sans-serif"
                color: Colors.on_surface
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                id: contentContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
