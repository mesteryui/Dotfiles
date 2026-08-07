pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Core.Services as Services
import qs.Primitives

Item {
    id: itemContainer

    required property var modelData  // <-- required

    implicitWidth: 32
    implicitHeight: 32

    function showMenu()
    {
        const w = loader.item
        if (w) w.visible = !w.visible
    }
    LazyLoader {
        id: loader
        loading: mouseManagement.pressed
        component: TrayMenu {
            id: trayMenu
            menu: itemContainer.modelData?.menu ?? null
            anchor.item: itemContainer
            anchor.margins.top: 13
            anchor.margins.bottom: 13
            anchor.edges: (Services.ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Right
            anchor.gravity: (Services.ConfigService.configs.bar.position == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Left
        }
    }
    Item {
        id: visualContent
        anchors.fill: parent

        IconImage {
            source: itemContainer.modelData?.icon ?? ""
            
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
    if (!itemContainer.modelData) return;
    const isRight = mouse.button === Qt.RightButton;
    const needsMenu = isRight || itemContainer.modelData.onlyMenu;
    if (needsMenu && itemContainer.modelData.hasMenu)
    {
        itemContainer.showMenu();
    } else if (!isRight) {
    itemContainer.modelData.activate();
}
}
}

HoverHandler {
    id: hoverHandler
}

WheelHandler {
    onWheel: event => {
    if (!itemContainer.modelData) return;
    const isHorizontal = event.angleDelta.x !== 0;
    itemContainer.modelData.scroll(
        isHorizontal ? Qt.Horizontal : Qt.Vertical,
        isHorizontal ? event.angleDelta.x : event.angleDelta.y
    );
}
}
}