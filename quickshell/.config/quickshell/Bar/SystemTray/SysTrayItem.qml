pragma ComponentBehavior: Bound

import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: itemContainer

    required property var modelData  // <-- required

    implicitWidth: 32
    implicitHeight: 32

    // El menú vive mientras está visible, no mientras se pulsa: en un
    // clic rápido `pressed` ya cayó cuando `onClicked` pide el item.
    property bool menuOpen: false

    function showMenu()
    {
        itemContainer.menuOpen = true;
        const w = loader.item
        if (w) w.visible = !w.visible
    }

    Connections {
        target: loader

        // Clic rapidísimo: el item aún no existía al pedirlo; al
        // llegar se muestra (la intención era abrir: parte oculto).
        function onItemChanged() {
            const w = loader.item;
            if (w && itemContainer.menuOpen && !w.visible)
                w.visible = true;
        }
    }

    Connections {
        target: loader.item

        function onDismissed() {
            itemContainer.menuOpen = false;
        }
    }

    LazyLoader {
        id: loader

        loading: mouseManagement.pressed || itemContainer.menuOpen
        component: TrayMenu {
            id: trayMenu

            menu: itemContainer.modelData?.menu ?? null
            anchor.item: itemContainer
            anchor.margins.top: 38
            anchor.margins.bottom: 38
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

        // Sin icono: inicial del título en vez de caja vacía.
        StyledText {
            anchors.centerIn: parent
            visible: (itemContainer.modelData?.icon ?? "") === ""
            text: String(itemContainer.modelData?.title ?? "?").trim().charAt(0).toUpperCase() || "?"
            font.pixelSize: 16
            font.weight: Font.Bold
            color: Appearance.md3.on_surface_variant
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