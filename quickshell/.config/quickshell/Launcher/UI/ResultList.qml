// --- ResultList: lista de resultados del launcher ---
// ListView + delegate + navegación con cycle + flash de borde.
// Vista por menú (ver Base/MenuModes.js `viewFor`): "list" (filas con
// título+sub) o "grid" (cuadrícula de iconos, hoy emojis). La API hacia
// AppLauncher no cambia: listModel, activeMode, isPinnedFn, count,
// currentIndex, currentData, resetView(), moveSelection(delta) y las
// señales activated(item) / highlighted(item). En grid se suma
// moveGrid(dx, dy) para navegar en 2D. No conoce modos ni servicios.
pragma ComponentBehavior: Bound

import qs.Core
import qs.Primitives
import "../Base/MenuModes.js" as MenuModes
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var listModel
    property string activeMode: ""
    // (id: string) => bool. Sin valor: ninguna app fijada.
    property var isPinnedFn: id => false

    // Vista activa según el menú. Para cambiar un menú, editar su
    // entrada `view` en MenuModes.defs().
    readonly property bool isGrid: MenuModes.viewFor(root.activeMode) === "grid"
    // Columnas visibles de la cuadrícula (para mover en vertical).
    readonly property int gridColumns: Math.max(1, Math.floor(grid.width / grid.cellWidth))

    readonly property int count: root.isGrid ? grid.count : view.count
    readonly property int currentIndex: root.isGrid ? grid.currentIndex : view.currentIndex
    readonly property var currentData: {
        const item = root.isGrid ? grid.currentItem : view.currentItem;
        return item ? item.modelData : null;
    }

    signal activated(var item)
    signal highlighted(var item)

    // Selección al principio (apertura).
    function resetView() {
        if (root.isGrid) {
            grid.currentIndex = 0;
            grid.positionViewAtBeginning();
        } else {
            view.currentIndex = 0;
            view.positionViewAtBeginning();
        }
    }

    // Al cambiar de vista (lista <-> cuadrícula), recoloca el scroll
    // para no heredar huecos de la otra vista.
    onIsGridChanged: {
        view.positionViewAtBeginning();
        grid.positionViewAtBeginning();
    }

    // Mueve la selección con cycle: del último vuelve al primero y viceversa.
    // Al dar la vuelta se avisa discreto: línea fina en el borde hacia
    // donde se saltó (arriba = al primero, abajo = al último).
    property bool wrapFlash: false
    property int wrapDir: 0

    Timer {
        id: wrapTimer

        interval: 220
        onTriggered: root.wrapFlash = false
    }

    function moveSelection(delta) {
        const v = root.isGrid ? grid : view;
        const n = v.count;
        if (n === 0)
            return;
        let i = v.currentIndex + delta;
        if (i < 0 || i >= n) {
            root.wrapDir = i < 0 ? -1 : 1;
            root.wrapFlash = true;
            wrapTimer.restart();
        }
        if (i < 0)
            i = n - 1;
        else if (i >= n)
            i = 0;
        v.currentIndex = i;
        v.positionViewAtIndex(i, root.isGrid ? GridView.Contain : ListView.Contain);
    }

    // Movimiento 2D para la cuadrícula (flechas). En lista equivale
    // a lineal (dy como delta) por seguridad.
    function moveGrid(dx, dy) {
        if (!root.isGrid) {
            root.moveSelection(dx + dy);
            return;
        }
        root.moveSelection(dx + dy * root.gridColumns);
    }

    ListView {
        id: view

        anchors.fill: parent
        visible: !root.isGrid
        clip: true
        spacing: 4
        // Delegados ya instanciados fuera de vista (~4 por lado):
        // scroll rápido sin crear/destruir en cada frame.
        cacheBuffer: 224
        currentIndex: count > 0 ? 0 : -1
        highlightMoveDuration: 100
        keyNavigationEnabled: false
        model: root.listModel

        onCountChanged: {
            // El modelo se resetea en caliente (apps, menús, emojis...):
            // volver arriba para no dejar huecos de scroll con el
            // contenido nuevo (era el "espacio vacío" al recargar).
            view.positionViewAtBeginning();
            // Tras un Supr la lista se reconstruye y el índice puede
            // quedar fuera de rango (ej. borras la última): se recorta
            // para no quedarse sin selección.
            if (count > 0) {
                if (currentIndex < 0 || currentIndex >= count)
                    currentIndex = Math.min(Math.max(0, currentIndex), count - 1);
                if (currentIndex === -1)
                    currentIndex = 0;
            }
            // El reseteo del modelo no siempre emite currentIndexChanged
            // (el índice puede conservar el valor) y el currentItem aún
            // puede ser nulo: diferir para que existan los delegados.
            Qt.callLater(() => root.highlighted(root.currentData));
        }
        onCurrentIndexChanged: root.highlighted(root.currentData)

        delegate: Rectangle {
            id: entryDelegate

            required property var modelData
            required property int index

            // En modo todo el modelData es el DesktopEntry crudo
            // (viene de appModel); en el resto, el wrapper
            // {kind,title,sub,iconName,appIcon,ch,...} de results.
            readonly property bool isRawApp: {
                const d = entryDelegate.modelData;
                return root.activeMode === "todo" && d && typeof d.execute === "function";
            }
            readonly property string dispTitle: isRawApp ? (modelData.name || "") : (modelData.title || "")
            readonly property string dispSub: isRawApp ? (modelData.comment || modelData.id || "") : ((modelData.cat ? modelData.cat + " · " : "") + (modelData.sub || ""))
            readonly property string dispAppIcon: isRawApp ? (modelData.icon || "") : (modelData.appIcon || "")
            readonly property string dispIconName: modelData.iconName || "circle"
            readonly property string dispCh: modelData.ch || ""
            readonly property bool dispPinned: isRawApp && (modelData.id || "") !== "" && root.isPinnedFn(modelData.id)

            width: view.width
            height: 56
            radius: 16
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 12

                // Icono según tipo
                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32

                    AppIcon {
                        anchors.fill: parent
                        source: entryDelegate.dispAppIcon
                        fallback: "image-missing"
                        visible: entryDelegate.dispAppIcon !== ""
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        iconName: entryDelegate.dispIconName
                        size: 24
                        color: Appearance.md3.primary
                        visible: entryDelegate.dispAppIcon === "" && entryDelegate.dispCh === ""
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: entryDelegate.dispCh
                        font.pixelSize: 24
                        visible: entryDelegate.dispCh !== ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: entryDelegate.dispTitle
                        font.pixelSize: 14
                        color: Appearance.md3.on_surface
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: entryDelegate.dispSub
                        font.pixelSize: 12
                        color: Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                // Chincheta de app fijada (Alt+P)
                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    iconName: "push_pin"
                    size: 18
                    color: Appearance.md3.primary
                    visible: entryDelegate.dispPinned
                }
            }

            Rectangle {
                id: stateLayer
                anchors.fill: parent
                radius: parent.radius
                property bool hovered: false
                property bool pressed: false
                color: Appearance.md3.on_surface
                opacity: pressed ? 0.12 : (hovered || entryDelegate.ListView.isCurrentItem) ? 0.08 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    stateLayer.hovered = true;
                    view.currentIndex = entryDelegate.index;
                }
                onExited: stateLayer.hovered = false
                onPressed: stateLayer.pressed = true
                onReleased: stateLayer.pressed = false
                onClicked: root.activated(entryDelegate.modelData)
            }
        }
    }

    GridView {
        id: grid

        anchors.fill: parent
        visible: root.isGrid
        clip: true
        cellWidth: 56
        cellHeight: 56
        // Igual que la lista: delegados ya instanciados fuera de vista.
        cacheBuffer: 224
        currentIndex: count > 0 ? 0 : -1
        highlightMoveDuration: 100
        keyNavigationEnabled: false
        model: root.listModel

        onCountChanged: {
            // Igual que la lista: volver arriba ante reseteos en
            // caliente y recortar el índice si quedó fuera de rango.
            grid.positionViewAtBeginning();
            if (count > 0) {
                if (currentIndex < 0 || currentIndex >= count)
                    currentIndex = Math.min(Math.max(0, currentIndex), count - 1);
                if (currentIndex === -1)
                    currentIndex = 0;
            }
            Qt.callLater(() => root.highlighted(root.currentData));
        }
        onCurrentIndexChanged: root.highlighted(root.currentData)

        delegate: Rectangle {
            id: gridDelegate

            required property var modelData
            required property int index

            readonly property string dispAppIcon: modelData.appIcon || ""
            readonly property string dispIconName: modelData.iconName || "circle"
            readonly property string dispCh: modelData.ch || ""
            readonly property bool dispFav: modelData.isFavorite ?? false
            readonly property bool dispRecent: (modelData.isRecent ?? false) && !gridDelegate.dispFav

            width: grid.cellWidth
            height: grid.cellHeight
            radius: 16
            color: "transparent"

            Item {
                anchors.centerIn: parent
                width: 36
                height: 36

                AppIcon {
                    anchors.fill: parent
                    source: gridDelegate.dispAppIcon
                    fallback: "image-missing"
                    visible: gridDelegate.dispAppIcon !== ""
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    iconName: gridDelegate.dispIconName
                    size: 24
                    color: Appearance.md3.primary
                    visible: gridDelegate.dispAppIcon === "" && gridDelegate.dispCh === ""
                }
                StyledText {
                    anchors.centerIn: parent
                    text: gridDelegate.dispCh
                    font.pixelSize: 26
                    visible: gridDelegate.dispCh !== ""
                }
            }

            // Estrella de favorito (Ctrl+Mayús+F), como el badge ★ de la lista.
            MaterialIcon {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 4
                iconName: "star"
                size: 12
                color: Appearance.md3.primary
                visible: gridDelegate.dispFav
            }

            // Reloj de reciente, como el badge ↻ de la lista.
            // Si es favorito y reciente, gana la estrella.
            MaterialIcon {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 4
                iconName: "history"
                size: 12
                color: Appearance.md3.on_surface_variant
                visible: gridDelegate.dispRecent
            }

            Rectangle {
                id: gridStateLayer
                anchors.fill: parent
                radius: parent.radius
                property bool hovered: false
                property bool pressed: false
                color: Appearance.md3.on_surface
                opacity: pressed ? 0.12 : (hovered || gridDelegate.GridView.isCurrentItem) ? 0.08 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    gridStateLayer.hovered = true;
                    grid.currentIndex = gridDelegate.index;
                }
                onExited: gridStateLayer.hovered = false
                onPressed: gridStateLayer.pressed = true
                onReleased: gridStateLayer.pressed = false
                onClicked: root.activated(gridDelegate.modelData)
            }
        }
    }

    // Líneas de borde al dar la vuelta a la lista (wrap).
    // Sin MouseArea: no interceptan clics, solo se ven.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 3
        radius: 2
        color: Appearance.md3.primary
        opacity: (root.wrapFlash && root.wrapDir > 0) ? 0.55 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 3
        radius: 2
        color: Appearance.md3.primary
        opacity: (root.wrapFlash && root.wrapDir < 0) ? 0.55 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }
}
