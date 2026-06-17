import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../Core/Services" as Services

Item {
    id: itemContainer

    required property var modelData  // <-- required
    required property var rootWindow // <-- required también por consistencia
    
    implicitWidth: 26
    implicitHeight: 26
    
    function showMenu() {
        trayMenu.visible = !trayMenu.visible
    }
    TrayMenu {
        id: trayMenu
        menu: itemContainer.modelData?.menu ?? null
        anchor.item: itemContainer
        anchor.margins.top: 13
        anchor.margins.bottom: 13
        anchor.edges: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Right
        anchor.gravity: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Left
    }

    Item {
        id: visualContent
        anchors.fill: parent
        
        IconImage {
            source: modelData?.icon ?? ""
            // Centrado absoluto con márgenes limpios
            anchors.centerIn: parent
            width: parent.width - 8  // Equivalente a margins: 4 por cada lado
            height: parent.height - 8
            visible: source !== ""
        }

        // El efecto de escala se aplica al contenido visual, 
        // evitando que el MouseArea o el sistema de layouts se vuelva loco
        scale: mouseManagement.pressed ? 1.25 : hoverHandler.hovered ? 1.10 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }
    }

    MouseArea {
        id: mouseManagement
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: false

        onClicked: mouse => {
            if (!modelData) return;
            const isRight = mouse.button === Qt.RightButton;
            const needsMenu = isRight || modelData.onlyMenu;
            if (needsMenu && modelData.hasMenu) {
                itemContainer.showMenu();
            } else if (!isRight) {
                modelData.activate();
            }
        }
    }

    HoverHandler {
        id: hoverHandler
    }

    WheelHandler {
        onWheel: event => {
            if (!modelData) return;
            const isHorizontal = event.angleDelta.x !== 0;
            modelData.scroll(
                isHorizontal ? Qt.Horizontal : Qt.Vertical,
                isHorizontal ? event.angleDelta.x : event.angleDelta.y
            );
        }
    }
}