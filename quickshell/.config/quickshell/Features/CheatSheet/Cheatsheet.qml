pragma ComponentBehavior: Bound

import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

/**
 * Cheatsheet
 * -----------
 * Fullscreen keybind cheatsheet overlay.
 *
 * Design notes:
 *  - Uses WlrLayershell.keyboardFocus: Exclusive (NOT a lock screen).
 *  - visible stays true for `hideAnimDuration` ms after `active` goes false
 *    so the fade-out actually gets to play.
 *  - Cards are distributed into balanced columns (poor man's masonry).
 *  - Filtering usa Services.FuzzySearch (fuzzy match reusable en cualquier
 *    menú) en vez de un indexOf() literal, así "sq" encuentra "Super+Q",
 *    "clsw" encuentra "Close Window", etc.
 */
PanelWindow {
    id: root

    property bool active: false
    readonly property int hideAnimDuration: 160

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    visible: root.active || hideTimer.running

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:cheatsheet"
    WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: hideTimer

        interval: root.hideAnimDuration
    }

    onActiveChanged: {
        if (active) {
            // El contenido es lazy: puede no existir aún en la primera
            // apertura (onLoaded del Loader lo resetea al completarse).
            sheetLoader.item?.resetOnOpen();
        } else {
            hideTimer.restart();
        }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            root.active = !root.active;
        }

        function show(): void {
            root.active = true;
        }

        function hide(): void {
            root.active = false;
        }
    }
    // qmllint disable unresolved-type
    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggle the cheatsheet"
        onPressed: {
            root.active = !root.active;
        }
    }

    // --- Scrim ---
    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Appearance.md3.shadow
        opacity: root.active ? 0.55 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.hideAnimDuration
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.active = false
        }
    }

    // --- Content (lazy) ---
    // La hoja es pesada (Repeaters + filtrado) y pasa oculta casi siempre:
    // se crea al abrir y se destruye al terminar el fade-out.
    Loader {
        id: sheetLoader

        anchors.fill: parent
        active: root.active || hideTimer.running
        asynchronous: true
        sourceComponent: sheetComp
        onLoaded: {
            if (root.active)
                item.resetOnOpen();
        }
    }

    Component {
        id: sheetComp

        Item {
            id: sheet

        anchors.fill: parent
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.98

        Behavior on opacity {
            NumberAnimation {
                duration: root.hideAnimDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.hideAnimDuration
                easing.type: Easing.OutCubic
            }
        }

        focus: root.active

        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (ctrl) {
                switch (event.key) {
                case Qt.Key_J:
                case Qt.Key_N:
                    sheet.moveSelection(1);
                    event.accepted = true;
                    return;
                case Qt.Key_K:
                case Qt.Key_P:
                    sheet.moveSelection(-1);
                    event.accepted = true;
                    return;
                case Qt.Key_H:
                    sheet.moveColumn(-1);
                    event.accepted = true;
                    return;
                case Qt.Key_L:
                    sheet.moveColumn(1);
                    event.accepted = true;
                    return;
                default:
                    break;
                }
            }
            switch (event.key) {
            case Qt.Key_Escape:
                root.active = false;
                event.accepted = true;
                break;
            case Qt.Key_Tab:
            case Qt.Key_Backtab:
                searchField.forceActiveFocus();
                event.accepted = true;
                break;
            case Qt.Key_Down:
                sheet.moveSelection(1);
                event.accepted = true;
                break;
            case Qt.Key_Up:
                sheet.moveSelection(-1);
                event.accepted = true;
                break;
            case Qt.Key_Left:
                sheet.moveColumn(-1);
                event.accepted = true;
                break;
            case Qt.Key_Right:
                sheet.moveColumn(1);
                event.accepted = true;
                break;
            case Qt.Key_PageDown:
                sheet.scrollBy(flick.height * 0.9);
                event.accepted = true;
                break;
            case Qt.Key_PageUp:
                sheet.scrollBy(-flick.height * 0.9);
                event.accepted = true;
                break;
            case Qt.Key_Home:
                sheet.activeBindIndex = 0;
                sheet.scrollToActiveItem();
                event.accepted = true;
                break;
            case Qt.Key_End:
                sheet.activeBindIndex = Math.max(0, sheet.flatBinds.length - 1);
                sheet.scrollToActiveItem();
                event.accepted = true;
                break;
            default:
                // Escribiendo con el foco fuera del buscador (p. ej. tras
                // clicar el fondo): reinyecta el carácter en vez de perderlo.
                // Se ignoran combinaciones con Ctrl/Alt/Meta (son atajos, no texto).
                if (!searchField.activeFocus && event.text.length > 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    searchField.text += event.text;
                    searchField.cursorPosition = searchField.text.length;
                    searchField.forceActiveFocus();
                    event.accepted = true;
                }
                break;
            }
        }

        // Swallow clicks so they don't fall through to the scrim's dismiss handler
        MouseArea {
            anchors.fill: parent
            onClicked: sheet.forceActiveFocus()
        }

        // --- Keyboard scrolling ---
        readonly property real scrollStep: 140

        NumberAnimation {
            id: scrollAnim

            target: flick
            property: "contentY"
            duration: 180
            easing.type: Easing.OutCubic
        }

        function scrollTo(y) {
            const maxY = Math.max(0, flick.contentHeight - flick.height);
            scrollAnim.stop();
            scrollAnim.to = Math.max(0, Math.min(maxY, y));
            scrollAnim.start();
        }

        function scrollBy(delta) {
            sheet.scrollTo(flick.contentY + delta);
        }

        // Reseteo al abrir (llamado desde onActiveChanged del root y
        // desde onLoaded del Loader en la primera apertura).
        function resetOnOpen() {
            searchField.text = "";
            sheet.activeBindIndex = 0;
            Qt.callLater(() => searchField.forceActiveFocus());
        }

        // --- Item-by-item keyboard navigation ---

        /// Flat list of all currently visible binds in display order
        /// (column 0 top→bottom, column 1 top→bottom, …)
        /// Each entry: { flatIndex, catIdx, bindIdx }
        property var flatBinds: []

        /// Index into flatBinds that is currently highlighted (-1 = none)
        property int activeBindIndex: -1

        /// Rebuild flatBinds whenever the masonry columns change.
        onColumnsChanged: {
            const list = [];
            let idx = 0;
            const cols = sheet.columns;
            for (let c = 0; c < cols.length; c++) {
                const col = cols[c];
                for (let r = 0; r < col.length; r++) {
                    const card = col[r];
                    for (let b = 0; b < card.binds.length; b++) {
                        list.push({
                            flatIndex: idx,
                            col: c,
                            cardInCol: r,
                            bindInCard: b
                        });
                        idx++;
                    }
                }
            }
            sheet.flatBinds = list;
            // Clamp activeBindIndex to valid range after filter changes.
            if (sheet.activeBindIndex >= list.length)
                sheet.activeBindIndex = Math.max(0, list.length - 1);
        }

        /// Move selection by `delta` rows, clamped to the list bounds.
        function moveSelection(delta) {
            if (sheet.flatBinds.length === 0)
                return;
            const next = Math.max(0, Math.min(sheet.flatBinds.length - 1, sheet.activeBindIndex + delta));
            sheet.activeBindIndex = next;
            sheet.scrollToActiveItem();
        }

        /// Move selection sideways by `delta` columns (-1 = left, +1 = right),
        /// landing on the item at roughly the same vertical position in the
        /// target column. No-op at the first/last column.
        function moveColumn(delta) {
            if (sheet.flatBinds.length === 0)
                return;
            const current = sheet.flatBinds[sheet.activeBindIndex];
            if (!current)
                return;

            const targetCol = current.col + delta;
            if (targetCol < 0 || targetCol >= sheet.columns.length)
                return;

            // How many binds precede the current one within its own column.
            let posInCol = 0;
            for (let i = 0; i < sheet.activeBindIndex; i++) {
                if (sheet.flatBinds[i].col === current.col)
                    posInCol++;
            }

            // Land on the item at the same position in the target column,
            // clamped if that column is shorter.
            const candidates = [];
            for (let i = 0; i < sheet.flatBinds.length; i++) {
                if (sheet.flatBinds[i].col === targetCol)
                    candidates.push(i);
            }
            if (candidates.length === 0)
                return;

            sheet.activeBindIndex = candidates[Math.min(posInCol, candidates.length - 1)];
            sheet.scrollToActiveItem();
        }

        /// Compute the global flat index of the first bind inside a given card entry.
        function firstIndexForCard(colIdx, cardInColIdx) {
            let idx = 0;
            const cols = sheet.columns;
            for (let c = 0; c < cols.length; c++) {
                const col = cols[c];
                for (let r = 0; r < col.length; r++) {
                    if (c === colIdx && r === cardInColIdx)
                        return idx;
                    idx += col[r].binds.length;
                }
            }
            return idx;
        }

        /// Scroll the flickable so that the active item is fully visible.
        /// Resolves the real delegate via the Repeaters and asks the card
        /// for its mapped coordinates — no height estimates, so wrapped
        /// descriptions can't push the selection out of view anymore.
        function scrollToActiveItem() {
            if (sheet.activeBindIndex < 0 || sheet.flatBinds.length === 0)
                return;

            const entry = sheet.flatBinds[sheet.activeBindIndex];
            if (!entry)
                return;

            // Los Repeaters pueden estar a mitad de reconstrucción al filtrar.
            const colItem = columnsRepeater.itemAt(entry.col);
            if (!colItem)
                return;
            const card = colItem.cardsRepeater.itemAt(entry.cardInCol);
            if (!card)
                return;
            card.ensureRowVisible(entry.bindInCard);
        }

        ColumnLayout {
            id: mainLayout
            anchors {
                fill: parent
                margins: 48
            }

            spacing: 20

            // ----------------------------------------------------------------
            // Search bar — pill con fondo explícito + icono de lupa
            // ----------------------------------------------------------------
            Item {
                id: searchWrapper
                Layout.fillWidth: false
                Layout.preferredWidth: 480
                Layout.alignment: Qt.AlignHCenter

                implicitHeight: 52

                // Fondo pill
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.shape.full
                    color: Appearance.md3.surface_container_high
                    border.width: searchField.activeFocus ? 2 : 1
                    border.color: searchField.activeFocus ? Appearance.md3.primary : Appearance.md3.outline_variant

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }

                // Ícono lupa
                MaterialIcon {
                    id: searchIcon
                    anchors {
                        left: parent.left
                        leftMargin: 16
                        verticalCenter: parent.verticalCenter
                    }

                    iconName: "search"
                    size: Appearance.font.pixelSize.large
                    color: searchField.activeFocus ? Appearance.md3.primary : Appearance.md3.on_surface_variant

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }

                TextField {
                    id: searchField
                    anchors {
                        left: searchIcon.right
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                        leftMargin: 8
                        rightMargin: 20
                    }

                    background: null
                    color: Appearance.md3.on_surface
                    placeholderText: Services.I18nService.getTranslation("cheatsheet.search_placeholder", "Buscar atajos de teclado…")
                    placeholderTextColor: Appearance.md3.on_surface_variant
                    selectedTextColor: Appearance.md3.on_secondary_container
                    selectionColor: Appearance.md3.secondary_container
                    font.family: Appearance.font.sans
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.variableAxes: Appearance.font.variableAxes.main
                    verticalAlignment: TextInput.AlignVCenter

                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        // Ctrl+letra: navegar sin salir del buscador.
                        // (El buscador acapara el foco; sin esto, ←/→/Home/End
                        //  del nivel sheet serían inalcanzables escribiendo.)
                        if (ctrl) {
                            switch (event.key) {
                            case Qt.Key_J:
                            case Qt.Key_N:
                                sheet.moveSelection(1);
                                event.accepted = true;
                                return;
                            case Qt.Key_K:
                            case Qt.Key_P:
                                sheet.moveSelection(-1);
                                event.accepted = true;
                                return;
                            case Qt.Key_H:
                                sheet.moveColumn(-1);
                                event.accepted = true;
                                return;
                            case Qt.Key_L:
                                sheet.moveColumn(1);
                                event.accepted = true;
                                return;
                            case Qt.Key_U:
                                searchField.text = "";
                                event.accepted = true;
                                return;
                            default:
                                break;
                            }
                        }
                        switch (event.key) {
                        case Qt.Key_Escape:
                            // 1º Esc con texto: limpia. 2º Esc (vacío): cierra.
                            if (searchField.text.length > 0) {
                                searchField.text = "";
                            } else {
                                root.active = false;
                            }
                            event.accepted = true;
                            break;
                        case Qt.Key_Tab:
                        case Qt.Key_Backtab:
                            // Atrapa el foco: no hay nada más enfocable aquí.
                            event.accepted = true;
                            break;
                        case Qt.Key_Down:
                            sheet.moveSelection(1);
                            event.accepted = true;
                            break;
                        case Qt.Key_Up:
                            sheet.moveSelection(-1);
                            event.accepted = true;
                            break;
                        case Qt.Key_PageDown:
                            sheet.scrollBy(flick.height * 0.9);
                            event.accepted = true;
                            break;
                        case Qt.Key_PageUp:
                            sheet.scrollBy(-flick.height * 0.9);
                            event.accepted = true;
                            break;
                        case Qt.Key_Home:
                            if (event.modifiers & Qt.ControlModifier) {
                                sheet.activeBindIndex = 0;
                                sheet.scrollToActiveItem();
                                event.accepted = true;
                            }
                            break;
                        case Qt.Key_End:
                            if (event.modifiers & Qt.ControlModifier) {
                                sheet.activeBindIndex = Math.max(0, sheet.flatBinds.length - 1);
                                sheet.scrollToActiveItem();
                                event.accepted = true;
                            }
                            break;
                        default:
                            break;
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // Hint de teclado — una línea, centrada, mismo tono que el placeholder
            // ----------------------------------------------------------------
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Services.I18nService.getTranslation("cheatsheet.hint", "Ctrl+J/K moverse · Ctrl+H/L columnas · Esc limpiar/cerrar")
                color: Appearance.md3.on_surface_variant
                font.pixelSize: Appearance.font.pixelSize.smaller
                opacity: 0.8
            }

            // ----------------------------------------------------------------
            // Masonry grid — solo visible cuando hay resultados
            // ----------------------------------------------------------------
            Flickable {
                id: flick
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(mainLayout.width, columnsRow.implicitWidth + 16)
                Layout.fillHeight: true

                visible: sheet.filteredCategories.length > 0
                contentWidth: Math.max(width, columnsRow.implicitWidth)
                contentHeight: columnsRow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: StyledScrollBar {}

                Row {
                    id: columnsRow

                    anchors.left: parent.left
                    spacing: 20

                    Repeater {
                        id: columnsRepeater

                        model: sheet.columns
                        delegate: Column {
                            required property var modelData
                            required property int index   // column index

                            width: sheet.columnWidth
                            spacing: 20

                            property alias cardsRepeater: cardsRep

                            Repeater {
                                id: cardsRep

                                model: parent.modelData
                                delegate: CheatsheetCategoryCard {
                                    required property var modelData
                                    required property int index   // card-in-column index

                                    width: parent?.width ?? 40
                                    category: modelData.category
                                    binds: modelData.binds
                                    // colIdx travels with the data (set in sheet.columns), so this
                                    // no longer depends on the item already being reparented —
                                    // fixes "Cannot read property 'colIdx' of null" during
                                    // Repeater teardown/recreate on filter changes.
                                    firstRowIndex: sheet.firstIndexForCard(modelData.colIdx, index)
                                    activeRowIndex: sheet.activeBindIndex
                                    flickRef: flick
                                    scrollToFunc: y => sheet.scrollTo(y)
                                    onRowHovered: globalIndex => sheet.activeBindIndex = globalIndex
                                }
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // Estado vacío — icono + texto centrados en el espacio disponible
            // ----------------------------------------------------------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: sheet.filteredCategories.length === 0

                M3Card {
                    anchors.centerIn: parent
                    width: emptyContent.implicitWidth + 56
                    height: emptyContent.implicitHeight + 48

                    Column {
                        id: emptyContent

                        anchors.centerIn: parent
                        spacing: 14

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            iconName: searchField.text.length > 0 ? "search_off" : (Services.HyprlandKeybinds.failed ? "error" : "keyboard")
                            size: 52
                            color: Services.HyprlandKeybinds.failed && searchField.text.length === 0 ? Appearance.md3.error : Appearance.md3.on_surface_variant
                            opacity: 0.55
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: searchField.text.length > 0 ? Services.I18nService.getTranslation("cheatsheet.empty_no_match", "Ningún atajo coincide con") + " \u201c" + searchField.text + "\u201d" : (Services.HyprlandKeybinds.failed ? Services.I18nService.getTranslation("cheatsheet.empty_error", "No se pudieron leer los atajos (¿hyprctl disponible?)") : Services.I18nService.getTranslation("cheatsheet.empty_no_binds", "No se encontraron atajos documentados"))
                            color: Appearance.md3.on_surface_variant
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }
                }
            }
        }

        // --- Filtering ---
        // Antes: indexOf() literal sobre b.searchText — exigía substring exacto
        // y no toleraba ni orden aproximado ni typos ("clw" no encontraba
        // "Close Window"). Ahora usa Services.FuzzySearch (el mismo motor
        // reusable en cualquier menú del shell): matchea por subsecuencia
        // con scoring, y ordena los binds de cada categoría por relevancia.
        // Cuando hay query, además las categorías se reordenan por su mejor
        // match, para que la categoría más relevante aparezca primero.
        property var filteredCategories: {
            const query = searchField.text.trim();
            const grouped = Services.HyprlandKeybinds.groupedKeybinds;
            const order = Services.HyprlandKeybinds.keybindCategories;
            const result = [];

            for (let i = 0; i < order.length; i++) {
                const cat = order[i];
                const binds = grouped[cat] || [];

                if (query.length === 0) {
                    if (binds.length > 0)
                        result.push({
                            category: cat,
                            binds: binds,
                            score: 0
                        });
                    continue;
                }

                const matches = Services.FuzzySearch.filter(query, binds, b => b.searchText);
                if (matches.length > 0)
                    result.push({
                        category: cat,
                        binds: matches.map(m => m.item) // ya vienen ordenados por score desc
                        ,
                        score: matches[0].score           // mejor score de la categoría
                    });
            }

            if (query.length > 0)
                result.sort((a, b) => b.score - a.score);

            return result;
        }

        onFilteredCategoriesChanged: {
            // Reset focus to the first item whenever search results change,
            // y vuelve arriba: sin esto el Flickable se quedaba a mitad de
            // lista tras filtrar y parecía que no había resultados.
            sheet.activeBindIndex = 0;
            scrollAnim.stop();
            flick.contentY = 0;
        }

        // --- Fixed column width + responsive column count ---
        readonly property int columnWidth: 380

        readonly property int desiredColumnCount: width > 1500 ? 3 : (width > 950 ? 2 : 1)

        property int columnCount: Math.max(1, Math.min(desiredColumnCount, filteredCategories.length || 1))

        // --- Balanced column distribution (greedy bin-packing by estimated height) ---
        property var columns: {
            const cats = sheet.filteredCategories;
            const count = sheet.columnCount;
            const cols = [];
            const heights = [];
            for (let c = 0; c < count; c++) {
                cols.push([]);
                heights.push(0);
            }

            const sorted = cats.slice().sort((a, b) => b.binds.length - a.binds.length);

            for (let i = 0; i < sorted.length; i++) {
                const entry = sorted[i];
                const estHeight = 60 + entry.binds.length * 46;
                let minIdx = 0;
                for (let c = 1; c < count; c++) {
                    if (heights[c] < heights[minIdx])
                        minIdx = c;
                }
                cols[minIdx].push(Object.assign({}, entry, {
                    colIdx: minIdx
                }));
                heights[minIdx] += estHeight + 20;
            }
            return cols;
        }
        }
    }
}
