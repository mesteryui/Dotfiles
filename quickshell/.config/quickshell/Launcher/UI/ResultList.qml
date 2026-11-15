// --- ResultList: lista de resultados del launcher ---
// ListView + delegate + navegación con cycle + flash de borde.
// Vista por menú (ver Base/MenuModes.js `viewFor`): "list" (filas con
// título+sub) o "grid" (cuadrícula de iconos). La API hacia AppLauncher
// no cambia: listModel, activeMode, isPinnedFn, count, currentIndex,
// currentData, resetView(), moveSelection(delta) y las señales
// activated(item) / highlighted(item). En grid se suma moveGrid(dx, dy).
// No conoce modos ni servicios.
//
// Rendimiento: el swap de modelo se hace diferido en dos pasos
// (null → nuevo) para evitar SIGSEGV en QQuickItemView::setModel.
// El reciclaje de delegados (reuseItems) se deja desactivado a propósito:
// con el swap en dos pasos el pool se lee a medio reasignar y las cajas
// muestran contenido vacío o de la fila anterior.
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
    // Item actual resuelto POR ÍNDICE desde el modelo, no desde el
    // delegado (view.currentItem): tras un swap de modelo los delegados
    // aún no existen cuando se emite el highlight y currentItem es null
    // -> el preview no se pedía nunca y nada lo reintentaba. Por índice
    // siempre es válido en cuanto el modelo está aplicado. `count` como
    // dependencia cubre los updates internos sin cambio de identidad.
    readonly property var currentData: {
        const c = root.count;
        void c;
        return root.itemAt(root.currentIndex);
    }

    // Array plano subyacente (vía única para itemAt/_indexOfKey/
    // neighborItems). OJO: NO se lee de view.model/grid.model: cuando el
    // origen es un array JS, la vista lo envuelve en un modelo interno
    // (Array.isArray falla y no hay .values) y todo resolvía a null.
    // El binding listModel crudo sí conserva los arrays reales.
    function _asArray(v) {
        if (!v)
            return null;
        if (Array.isArray(v))
            return v;
        if (typeof v.length === "number") {
            const out = [];
            for (let i = 0; i < v.length; i++)
                out.push(v[i]);
            return out;
        }
        return null;
    }

    function _rawArray() {
        const m = root.listModel;
        if (Array.isArray(m))
            return m;
        // ListModel: convertir a array plano para poder indexar.
        if (m && typeof m.count === "number" && typeof m.get === "function") {
            const arr = [];
            for (let i = 0; i < m.count; i++)
                arr.push(m.get(i));
            return arr;
        }
        if (m && m.values !== undefined) {
            const arr = root._asArray(m.values);
            if (arr)
                return arr;
        }
        return root._asArray(m);
    }

    function itemAt(idx) {
        const arr = root._rawArray();
        if (!arr || idx < 0 || idx >= arr.length)
            return null;
        return arr[idx] || null;
    }

    signal activated(var item)

    signal highlighted(var item)

    // Generación del filtro: distingue "nueva búsqueda" (query/modo =>
    // ir arriba) de "refresco de datos" (snapshot de fd, Supr en clip,
    // rescan .desktop => conservar selección y scroll). Solo cambia con
    // el filtro efectivo.
    property int filterEpoch: 0

    property int _seenEpoch: -1

    // Marca de la última navegación por teclado: el hover del ratón no
    // debe robar la selección justo después (jitter del puntero).
    property double _lastKeyNav: 0

    // Clave estable del item para conservar la selección entre swaps de
    // modelo: al estrechar el filtro, el item sigue seleccionado si aún
    // está en la lista (comportamiento rofi/walker). Por modo porque
    // cada menú identifica sus items de forma distinta.
    function _keyOf(item) {
        if (!item)
            return "";
        switch (root.activeMode) {
        case "todo":
            return "app:" + (item.id || "");
        case "clip":
            return "clip:" + (item.cid || "");
        case "files":
            return "file:" + (item.path || "");
        case "emoji":
            return "emoji:" + (item.ch || "");
        case "system":
            return "sys:" + (item.section || "") + "|" + (item.title || "") + "|" + (item.shell || "");
        default:
            return "t:" + (item.title || "");
        }
    }

    function _indexOfKey(key) {
        if (key === "")
            return -1;
        const arr = root._rawArray();
        if (!arr)
            return -1;
        for (let i = 0; i < arr.length; i++)
            if (root._keyOf(arr[i]) === key)
                return i;
        return -1;
    }

    // Vecinos del item actual (±2) para prefetch de previews.
    function neighborItems() {
        const arr = root._rawArray();
        if (!arr || arr.length === 0)
            return [];
        const v = root.isGrid ? grid : view;
        const len = Math.min(arr.length, v.count > 0 ? v.count : arr.length);
        if (len === 0)
            return [];
        const cur = Math.min(Math.max(0, v.currentIndex), len - 1);
        const out = [];
        for (let d = -2; d <= 2; d++) {
            if (d === 0)
                continue;
            const i = cur + d;
            if (i >= 0 && i < len)
                out.push(arr[i]);
        }
        return out;
    }

    // Última clave mostrada en el preview: si tras un swap sigue el mismo
    // item (típico tecleando con un solo resultado), no se reconstruye.
    property string _shownKey: ""

    // Última clave válida de selección: sobrevive a los huecos con
    // modelo null para restaurar al aterrizar el nuevo.
    property string _lastKey: ""

    // Anota la selección actual como clave. Solo con item válido.
    function _noteIndex() {
        const cur = root.currentData;
        if (cur)
            root._lastKey = root._keyOf(cur);
    }

    // Asienta vista tras un cambio de modelo o de conteo.
    // Nueva búsqueda => primer item; refresco => conservar sitio.
    function _settle() {
        const v = root.isGrid ? grid : view;
        const isFilter = root.filterEpoch !== root._seenEpoch;
        root._seenEpoch = root.filterEpoch;
        if (v.count === 0) {
            v.currentIndex = -1;
            root._swapping = false;
            root._shownKey = "";
            root.highlighted(root.currentData);
            return;
        }
        if (isFilter) {
            v.currentIndex = 0;
            v.positionViewAtBeginning();
        } else {
            const idx = root._indexOfKey(root._lastKey);
            if (idx >= 0)
                v.currentIndex = idx;
            else if (v.currentIndex < 0)
                v.currentIndex = 0;
            else if (v.currentIndex >= v.count)
                v.currentIndex = v.count - 1;
            v.positionViewAtIndex(v.currentIndex, root.isGrid ? GridView.Contain : ListView.Contain);
        }
        root._noteIndex();
        root._swapping = false;
        const _cur = root.currentData;
        const _k = root._keyOf(_cur);
        if (_k !== root._shownKey || !isFilter) {
            root._shownKey = _k;
            root.highlighted(_cur);
        }
    }

    // Durante el swap de modelo los delegados se destruyen/recrean y el
    // índice pasa por -1: con este flag los velos no animan y el preview
    // se actualiza una sola vez al asentar.
    property bool _swapping: false

    // Aplicación del modelo. El swap se hace en dos pasos diferidos
    // (null → nuevo) para evitar SIGSEGV en QQuickItemView::setModel.
    property int _modelGen: 0

    function _requestApply() {
        const gen = ++root._modelGen;
        root._swapping = true;
        Qt.callLater(() => {
            if (gen !== root._modelGen)
                return;
            const m = root.listModel;
            const wantView = root.isGrid ? null : m;
            const wantGrid = root.isGrid ? m : null;
            if (view.model === wantView && grid.model === wantGrid) {
                if (root.filterEpoch !== root._seenEpoch)
                    Qt.callLater(() => root._settle());
                root._swapping = false;
                return;
            }
            // Swap diferido en dos pasos.
            view.model = null;
            grid.model = null;
            Qt.callLater(() => {
                if (gen !== root._modelGen)
                    return;
                if (root.isGrid)
                    grid.model = root.listModel;
                else
                    view.model = root.listModel;
                Qt.callLater(() => {
                    if (gen !== root._modelGen)
                        return;
                    root._settle();
                });
            });
        });
    }

    onListModelChanged: root._requestApply()

    // Cambio de filtro (query/modo/sección): puede venir sin cambio de
    // identidad del modelo, así que se re-solicita el asentamiento.
    onFilterEpochChanged: root._requestApply()

    Component.onCompleted: root._requestApply()

    // Selección al principio (apertura).
    function resetView() {
        Qt.callLater(() => {
            root._lastKey = "";
            if (root.isGrid) {
                grid.currentIndex = 0;
                grid.positionViewAtBeginning();
            } else {
                view.currentIndex = 0;
                view.positionViewAtBeginning();
            }
            root._shownKey = root._keyOf(root.currentData);
            root.highlighted(root.currentData);
        });
    }

    // Al cambiar de vista (lista <-> cuadrícula).
    onIsGridChanged: {
        root._requestApply();
        Qt.callLater(() => {
            view.positionViewAtBeginning();
            grid.positionViewAtBeginning();
        });
    }

    // Mueve la selección con cycle.
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
        root._lastKeyNav = Date.now();
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

    // Movimiento 2D para la cuadrícula.
    function moveGrid(dx, dy) {
        if (!root.isGrid) {
            root.moveSelection(dx + dy);
            return;
        }
        const n = grid.count;
        if (n === 0)
            return;
        root._lastKeyNav = Date.now();
        const cols = Math.max(1, root.gridColumns);
        const cur = Math.min(Math.max(0, grid.currentIndex), n - 1);
        const maxRow = Math.floor((n - 1) / cols);
        const newRow = Math.min(maxRow, Math.max(0, Math.floor(cur / cols) + dy));
        const rowLen = (newRow === maxRow) ? (n - newRow * cols) : cols;
        const newCol = Math.min(rowLen - 1, Math.max(0, (cur % cols) + dx));
        const i = newRow * cols + newCol;
        grid.currentIndex = i;
        grid.positionViewAtIndex(i, GridView.Contain);
    }

    ListView {
        id: view

        anchors.fill: parent
        visible: !root.isGrid
        clip: true
        spacing: Appearance.spacing.extraSmall
        // Delegados ya instanciados fuera de vista: scroll rápido sin
        // crear/destruir en cada frame.
        cacheBuffer: 224
        // Sin reciclaje de delegados: el swap de modelo en dos pasos
        // (null → nuevo) devuelve los delegados al pool y el reciclado se
        // lee a medio reasignar, dejando cajas vacías o con el contenido
        // anterior. Las listas son cortas y el filtrado va con debounce:
        // crear/destruir es despreciable aquí.
        reuseItems: false
        currentIndex: -1
        highlightMoveDuration: 100
        keyNavigationEnabled: false
        // Sin binding de modelo: lo aplica _requestApply() diferido.

        onCountChanged: {
            Qt.callLater(() => {
                root._settle();
            });
        }
        onCurrentIndexChanged: {
            root._noteIndex();
            if (!root._swapping)
                root.highlighted(root.currentData);
        }

        delegate: Rectangle {
            id: entryDelegate

            required property var modelData
            required property int index

            // En modo todo el modelData es el snapshot plano de la app
            // (viene de appModel); en el resto, el wrapper
            // {kind,title,sub,icon,appIcon,ch,...} de results.
            readonly property bool isRawApp: {
                const d = entryDelegate.modelData;
                return root.activeMode === "todo" && d && d.isDesktopApp === true;
            }
            readonly property string dispTitle: isRawApp ? (modelData.name || "") : (modelData.title || "")
            // `cat` (categoría/sección) NO se muestra en el sub: el modo
            // actual ya se sabe por el modo/chips. Mostrarlo duplica
            // información y alarga la sub innecesariamente.
            readonly property string dispSub: isRawApp ? (modelData.comment || modelData.id || "") : (
                                                             modelData.sub || "")
            readonly property string dispAppIcon: isRawApp ? (modelData.icon || "") : (modelData.appIcon
                                                                                       || "")
            readonly property string dispIcon: modelData.icon || "circle"
            readonly property string dispCh: modelData.ch || ""
            readonly property bool dispPinned: isRawApp && (modelData.id || "") !== "" && root.isPinnedFn(
                                                   modelData.id)

            readonly property bool effSelected: entryDelegate.ListView.isCurrentItem || (view.count === 1
                                                                                         && root._swapping)

            Accessible.role: Accessible.ListItem
            Accessible.name: entryDelegate.dispTitle
            Accessible.description: entryDelegate.dispSub

            // width: parent.width ocupa todo el ancho del ListView; el
            // RowLayout interno (fillWidth) reparte el resto. `parent` es
            // null mientras el delegado entra/sale del pool: sin la guarda
            // QML avisa de "Cannot read property 'width' of null".
            width: parent ? parent.width : 0
            height: 64
            radius: Appearance.shape.large
            color: "transparent"
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: Appearance.spacing.small
                spacing: Appearance.spacing.medium
                Layout.fillWidth: true

                // Icono según tipo
                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.maximumWidth: 32

                    AppIcon {
                        anchors.fill: parent
                        source: entryDelegate.dispAppIcon
                        fallback: "image-missing"
                        visible: entryDelegate.dispAppIcon !== ""
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: entryDelegate.dispIcon
                        size: 24
                        color: entryDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                           Appearance.md3.primary
                        visible: entryDelegate.dispAppIcon === "" && entryDelegate.dispCh === ""
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: entryDelegate.dispCh
                        font.pixelSize: 24
                        color: entryDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                           Appearance.md3.on_surface
                        visible: entryDelegate.dispCh !== ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 9999
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 9999
                        text: entryDelegate.dispTitle
                        // Contenido del usuario (portapapeles, nombres de
                        // archivo): nunca interpretarlo como rich text.
                        textFormat: Text.PlainText
                        font.pixelSize: Appearance.typeScale.bodyMedium
                        color: entryDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                           Appearance.md3.on_surface
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 9999
                        text: entryDelegate.dispSub
                        textFormat: Text.PlainText
                        font.pixelSize: Appearance.typeScale.labelMedium
                        color: entryDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                           Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                // Chincheta de app fijada (Alt+P)
                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "push_pin"
                    size: 20
                    color: entryDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                       Appearance.md3.primary
                    visible: entryDelegate.dispPinned
                }
            }

            M3StateLayer {
                id: stateLayer
                anchors.fill: parent
                radius: parent.radius
                tint: entryDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                  Appearance.md3.on_surface
                animate: !root._swapping
            }

            M3SelectionFill {
                anchors.fill: parent
                radius: parent.radius
                selected: entryDelegate.effSelected
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    stateLayer.hovered = true;
                    if (Date.now() - root._lastKeyNav > 300)
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
        cacheBuffer: 224
        // Mismo motivo que en la lista: el reciclaje de delegados con el
        // swap de modelo (null → nuevo) deja contenido obsoleto.
        reuseItems: false
        currentIndex: -1
        highlightMoveDuration: 100
        keyNavigationEnabled: false

        onCountChanged: {
            Qt.callLater(() => {
                root._settle();
            });
        }
        onCurrentIndexChanged: {
            root._noteIndex();
            if (!root._swapping)
                root.highlighted(root.currentData);
        }

        delegate: Rectangle {
            id: gridDelegate

            required property var modelData
            required property int index

            readonly property string dispAppIcon: modelData.appIcon || ""
            readonly property string dispIcon: modelData.icon || "circle"
            readonly property string dispCh: modelData.ch || ""
            readonly property bool dispFav: modelData.isFavorite ?? false
            readonly property bool dispRecent: (modelData.isRecent ?? false) && !gridDelegate.dispFav
            readonly property bool effSelected: gridDelegate.GridView.isCurrentItem || (grid.count === 1
                                                                                        && root._swapping)

            Accessible.role: Accessible.ListItem
            Accessible.name: gridDelegate.dispCh !== "" ? gridDelegate.dispCh : gridDelegate.dispIcon

            width: grid.cellWidth
            height: grid.cellHeight
            radius: Appearance.shape.large
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
                    icon: gridDelegate.dispIcon
                    size: 24
                    color: gridDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                      Appearance.md3.primary
                    visible: gridDelegate.dispAppIcon === "" && gridDelegate.dispCh === ""
                }
                StyledText {
                    anchors.centerIn: parent
                    text: gridDelegate.dispCh
                    font.pixelSize: 26
                    color: gridDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                      Appearance.md3.on_surface
                    visible: gridDelegate.dispCh !== ""
                }
            }

            MaterialIcon {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Appearance.spacing.extraSmall
                icon: "star"
                size: 12
                color: gridDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                  Appearance.md3.primary
                visible: gridDelegate.dispFav
            }

            MaterialIcon {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Appearance.spacing.extraSmall
                icon: "history"
                size: 12
                color: gridDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                  Appearance.md3.on_surface_variant
                visible: gridDelegate.dispRecent
            }

            M3StateLayer {
                id: gridStateLayer
                anchors.fill: parent
                radius: parent.radius
                tint: gridDelegate.effSelected ? Appearance.md3.on_secondary_container :
                                                 Appearance.md3.on_surface
                animate: !root._swapping
            }

            M3SelectionFill {
                anchors.fill: parent
                radius: parent.radius
                selected: gridDelegate.effSelected
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    gridStateLayer.hovered = true;
                    if (Date.now() - root._lastKeyNav > 300)
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
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 3
        radius: Appearance.shape.micro
        color: Appearance.md3.primary
        opacity: (root.wrapFlash && root.wrapDir > 0) ? 0.55 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.motion.fast
            }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 3
        radius: Appearance.shape.micro
        color: Appearance.md3.primary
        opacity: (root.wrapFlash && root.wrapDir < 0) ? 0.55 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.motion.fast
            }
        }
    }
}
