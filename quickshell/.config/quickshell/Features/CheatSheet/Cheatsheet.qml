pragma ComponentBehavior: Bound

import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

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
            searchField.text = "";
            sheet.activeBindIndex = 0;
            Qt.callLater(() => searchField.forceActiveFocus());
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

    // --- Content ---
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
            switch (event.key) {
            case Qt.Key_Escape:
                root.active = false;
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
                if (!searchField.activeFocus && event.text.length > 0) {
                    searchField.forceActiveFocus();
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
        function scrollToActiveItem() {
            if (sheet.activeBindIndex < 0 || sheet.flatBinds.length === 0)
                return;

            // Estimate the Y position of the active item inside the flickable's content.
            // We can't use mapToItem on the delegate directly from here (it's in a
            // Repeater inside a Column inside a Row), so we approximate via the
            // column heights computed by the bin-packing algorithm.
            const entry = sheet.flatBinds[sheet.activeBindIndex];
            if (!entry)
                return;

            const cols = sheet.columns;
            // Height of all cards preceding our card in the same column.
            let cardTop = 0;
            for (let r = 0; r < entry.cardInCol; r++) {
                cardTop += 60 + cols[entry.col][r].binds.length * 46 + 20; // estHeight + gap
            }
            // Offset inside the card: header ~(36 + 6 bottomMargin) + rows before us.
            const rowHeight = 46;
            const headerHeight = 42;
            const cardPadding = 20;
            const itemTop = cardTop + cardPadding + headerHeight + entry.bindInCard * rowHeight;
            const itemBottom = itemTop + rowHeight;

            const viewTop = flick.contentY;
            const viewBottom = viewTop + flick.height;

            if (itemTop < viewTop) {
                sheet.scrollTo(itemTop - 8);
            } else if (itemBottom > viewBottom) {
                sheet.scrollTo(itemBottom - flick.height + 8);
            }
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
                    placeholderText: Services.I18nService.getTranslation("cheatsheet.search", "Search keybinds…")
                    placeholderTextColor: Appearance.md3.on_surface_variant
                    selectedTextColor: Appearance.md3.on_secondary_container
                    selectionColor: Appearance.md3.secondary_container
                    font.family: Appearance.font.sans
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.variableAxes: Appearance.font.variableAxes.main
                    verticalAlignment: TextInput.AlignVCenter

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            root.active = false;
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
                        model: sheet.columns
                        delegate: Column {
                            required property var modelData
                            required property int index   // column index
                            width: sheet.columnWidth
                            spacing: 20

                            Repeater {
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
                            iconName: searchField.text.length > 0 ? "search_off" : "keyboard"
                            size: 52
                            color: Appearance.md3.on_surface_variant
                            opacity: 0.55
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: searchField.text.length > 0 ? Services.I18nService.getTranslation("cheatsheet.no_match", "No keybinds match") + " \u201c" + searchField.text + "\u201d" : Services.I18nService.getTranslation("cheatsheet.no_binds", "No documented keybinds found")
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
            // Reset focus to the first item whenever search results change.
            sheet.activeBindIndex = 0;
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
