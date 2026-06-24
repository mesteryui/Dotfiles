import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Core
import qs.Core.Services as Services

PanelWindow {
    id: root
    
    property string menuTitle: ""
    property alias content: contentContainer.data
    default property alias data: contentContainer.data
    
    // Las ventanas (PanelWindow) usan implicitWidth/Height según la nueva API.
    // Usamos tamaños fijos mínimos o calculados en base al contenido, pero sin enlazar directamente el layout.
    implicitWidth: 300
    implicitHeight: 400

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
        color: Appearance.md3.surface
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
            border.color: Appearance.md3.outline_variant
            radius: parent.radius
            z: 10
        }

        ColumnLayout {
            id: mainLayout
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            Text {
                id: titleText
                text: root.menuTitle
                visible: text !== ""
                font.family: Services.ConfigService.configs.appearence.fontSans
                color: Appearance.md3.on_surface
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                
                // Text ya calcula su implicitWidth automáticamente
            }

            Item {
                id: contentContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                // Quitamos el binding loop: Layout gestiona el tamaño automáticamente
            }
        }
    }
}
