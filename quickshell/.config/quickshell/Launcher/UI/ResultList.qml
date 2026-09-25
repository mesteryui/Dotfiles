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
    // Item actual resuelto POR ÍNDICE desde el modelo, no desde el
    // delegado (view.currentItem): tras un swap de modelo los delegados
    // aún no existen cuando se emite el highlight y currentItem es null
    // -> el preview no se pedía nunca y nada lo reintentaba. Por índice
    // siempre es válido en cuanto el modelo está aplicado. `count` como
    // dependencia cubre los updates internos sin cambio de identidad
    // (ScriptModel del modo todo).
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
    // OJO2: en modo todo el modelo es un ScriptModel cuyo `values` es
    // list<var> (array-like: tiene length e índice pero Array.isArray
    // es false y puede no traer .map). Por eso se normaliza a Array JS
    // real: sin esto itemAt() devolvía null en modo todo y Enter no
    // ejecutaba nada (el click sí, porque el delegate pasa modelData).
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

    // Generación del filtro (la pone AppLauncher): distingue "nueva
    // búsqueda" (query/modo/sección => ir arriba) de "refresco de datos"
    // (snapshot de fd, Supr en clip, rescan .desktop => conservar
    // selección y scroll).
    property int filterEpoch: 0
    property int _seenEpoch: -1

    // Marca de la última navegación por teclado: el hover del ratón no
    // debe robar la selección justo después (jitter del puntero).
    property double _lastKeyNav: 0

    // Clave estable del item para conservar la selección entre swaps de
    // modelo: al estrechar el filtro, el item sigue seleccionado si aún
    // está en la lista (comportamiento rofi/walker). Por modo porque cada
    // menú identifica sus items de forma distinta.
    function _keyOf(item) {
        if (!item)
            return "";
        switch (root.activeMode) {
        case "todo": return "app:" + (item.id || "");
        case "clip": return "clip:" + (item.cid || "");
        case "files": return "file:" + (item.path || "");
        case "emoji": return "emoji:" + (item.ch || "");
        case "system": return "sys:" + (item.section || "") + "|" + (item.title || "") + "|" + (item.shell || "");
        default: return "t:" + (item.title || "");
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

    // Vecinos del item actual (±2) para prefetch de previews: al moverse,
    // el siguiente highlight suele ser caché y se siente instantáneo.
    // OJO: se indexa sobre el array crudo (ver _rawArray), no sobre el
    // modelo de la vista, y se recorta al conteo visible por si el modelo
    // aún no se aplicó del todo.
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

    // Última clave válida de selección (ver _keyOf): sobrevive a los
    // huecos con modelo null para restaurar al aterrizar el nuevo.
    property string _lastKey: ""

    // Anota la selección actual como clave. Solo con item válido: durante
    // la demolición (currentData null) se conserva la anterior.
    function _noteIndex() {
        const cur = root.currentData;
        if (cur)
            root._lastKey = root._keyOf(cur);
    }

    // Asienta vista tras un cambio de modelo o de conteo. Vía única para
    // no duplicar políticas entre _requestApply y onCountChanged (los
    // updates internos del ScriptModel en modo todo no pasan por apply).
    function _settle() {
        const v = root.isGrid ? grid : view;
        const isFilter = root.filterEpoch !== root._seenEpoch;
        root._seenEpoch = root.filterEpoch;
        if (v.count === 0) {
            v.currentIndex = -1;
            return;
        }
        if (isFilter) {
            // Nueva búsqueda/modo/sección: el item conservado sigue
            // mandando si existe; si no, arriba del todo.
            const idx = root._indexOfKey(root._lastKey);
            v.currentIndex = idx >= 0 ? idx : 0;
            v.positionViewAtBeginning();
        } else {
            // Refresco de datos (snapshot fd, Supr en clip, rescan):
            // conservar sitio; recortar solo si quedó fuera de rango y
            // asegurar visible sin saltos.
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
    }

    // Aplicación diferida del modelo (anti-SIGSEGV).
    // Cada tecla/cambio de modo reevalúa `listModel` con una identidad
    // nueva (ScriptModel vs array fresco). Bindear `view.model` directo a
    // eso llamaba a QQuickItemView::setModel de forma síncrona en mitad de
    // notificaciones del DelegateModel en curso -> SIGSEGV leyendo
    // delegados a medio construir/destruir (10 coredumps con el mismo
    // stack, tb. con items 100% planos del modo sistema). Por eso el swap
    // es diferido y en dos pasos: primero null (el modelo viejo se
    // desengancha limpio) y en el siguiente tick el nuevo. El contador de
    // generación descarta pasadas obsoletas si llegan varios cambios
    // seguidos (tecleo rápido).
    property int _modelGen: 0

    function _requestApply() {
        const gen = ++root._modelGen;
        Qt.callLater(() => {
            if (gen !== root._modelGen)
                return;
            const m = root.listModel;
            const wantView = root.isGrid ? null : m;
            const wantGrid = root.isGrid ? m : null;
            if (view.model === wantView && grid.model === wantGrid)
                return;
            // La selección a conservar vive en _lastKey (ver _noteIndex):
            // sobrevive a los huecos con modelo null.
            view.model = null;
            grid.model = null;
            Qt.callLater(() => {
                if (gen !== root._modelGen)
                    return;
                if (root.isGrid)
                    grid.model = root.listModel;
                else
                    view.model = root.listModel;
                // Índice+scroll en otro tick más: tocarlos en el mismo tick
                // del setModel reentra en el DelegateModel (SIGSEGV).
                // _settle() centraliza la política (ver arriba).
                Qt.callLater(() => {
                    if (gen !== root._modelGen)
                        return;
                    root._settle();
                });
            });
        });
    }

    onListModelChanged: root._requestApply()

    Component.onCompleted: root._requestApply()

    // Selección al principio (apertura). Diferido un frame: onOpened lo
    // llama en el mismo tick en que cambian debouncedQuery/activeMode
    // (setModel en curso); tocar currentIndex/scroll de forma síncrona
    // ahí reentra en el DelegateModel a medio resetear y tira el shell
    // (SIGSEGV en QQuickItemView::setModel). Con callLater el modelo ya
    // está estable cuando se recoloca la vista.
    function resetView() {
        Qt.callLater(() => {
            // Apertura: sin herencia de la sesión anterior.
            root._lastKey = "";
            if (root.isGrid) {
                grid.currentIndex = 0;
                grid.positionViewAtBeginning();
            } else {
                view.currentIndex = 0;
                view.positionViewAtBeginning();
            }
        });
    }

    // Al cambiar de vista (lista <-> cuadrícula), aplica el modelo a la
    // vista que toca y recoloca el scroll para no heredar huecos de la
    // otra vista. Diferido por el mismo motivo que resetView: el swap de
    // modelos aún está en curso.
    onIsGridChanged: {
        root._requestApply();
        Qt.callLater(() => {
            view.positionViewAtBeginning();
            grid.positionViewAtBeginning();
        });
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

    // Movimiento 2D para la cuadrícula con clamp por filas/columnas:
    // el vertical no da la vuelta a toda la lista (se queda en la primera
    // o última fila) y la última fila corta recorta la columna. En lista
    // equivale a lineal (dy como delta) por seguridad.
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
        spacing: 4
        // Delegados ya instanciados fuera de vista (~4 por lado):
        // scroll rápido sin crear/destruir en cada frame.
        // Sin reciclaje de delegados (reuseItems): con swaps de modelo por
        // cada tecla, el pool reciclado se leía a medio resetear
        // (SIGSEGV en setModel). Las listas son cortas y el filtrado ya va
        // con debounce: crear/destruir es despreciable aquí.
        cacheBuffer: 224
        reuseItems: false
        // Sin binding currentIndex<-count: escribir currentIndex de forma
        // síncrona durante el reset del DelegateModel (setModel en curso
        // por cada tecla) reentra en QtQmlModels y tira el shell con
        // SIGSEGV en QQuickItemView::setModel. El índice se gestiona solo
        // vía callLater (onCountChanged / resetView).
        currentIndex: -1
        highlightMoveDuration: 100
        keyNavigationEnabled: false
        // Sin binding de modelo: lo aplica _requestApply() diferido y en
        // dos pasos (ver arriba). Un binding directo re-evaluaba setModel
        // síncrono por cada tecla/cambio de modo -> SIGSEGV.

        onCountChanged: {
            // Todo diferido: este handler corre en mitad del reset del
            // modelo; mutar currentIndex/scroll aquí mismo reentra en
            // QtQmlModels. _settle() aplica la política única (nueva
            // búsqueda => arriba/restaurar; refresco => conservar sitio).
            Qt.callLater(() => {
                root._settle();
                // El reseteo del modelo no siempre emite currentIndexChanged
                // (el índice puede conservar el valor) y el currentItem aún
                // puede ser nulo: diferir para que existan los delegados.
                root.highlighted(root.currentData);
            });
        }
        onCurrentIndexChanged: {
            root._noteIndex();
            root.highlighted(root.currentData);
        }

        delegate: Rectangle {
            id: entryDelegate

            required property var modelData
            required property int index

            // En modo todo el modelData es el snapshot plano de la app
            // (viene de appModel); en el resto, el wrapper
            // {kind,title,sub,iconName,appIcon,ch,...} de results.
            readonly property bool isRawApp: {
                const d = entryDelegate.modelData;
                return root.activeMode === "todo" && d && d.isDesktopApp === true;
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
                    // El puntero no roba la selección al teclado: tras
                    // navegar con teclas se ignora el hover unos ms
                    // (jitter del ratón al teclear/moverse).
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
        // Igual que la lista: sin reciclaje (ver comentario en view).
        cacheBuffer: 224
        reuseItems: false
        // Igual que la lista: sin binding currentIndex<-count (reentrancia
        // en el DelegateModel durante setModel -> SIGSEGV). Gestión
        // imperativa diferida en onCountChanged / resetView.
        currentIndex: -1
        highlightMoveDuration: 100
        keyNavigationEnabled: false
        // Sin binding de modelo: lo aplica _requestApply() (ver arriba).

        onCountChanged: {
            // Igual que la lista: asentar diferido con la política única
            // (ver _settle) en vez de ir arriba siempre.
            Qt.callLater(() => {
                root._settle();
                root.highlighted(root.currentData);
            });
        }
        onCurrentIndexChanged: {
            root._noteIndex();
            root.highlighted(root.currentData);
        }

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
                    // Igual que la lista: el hover no roba al teclado.
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
