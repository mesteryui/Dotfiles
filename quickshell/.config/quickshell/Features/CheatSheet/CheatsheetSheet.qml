// CheatsheetSheet — menú de atajos con pestañas laterales.
// Izquierda: categorías (navigation-drawer M3). Derecha: atajos de la
// categoría activa. La búsqueda filtra ambas columnas y selecciona la
// primera categoría con resultados.
pragma ComponentBehavior: Bound
import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // `active` la pone el wrapper (Scope); al cerrar se emite para que
    // el Scope apague (el fade-out lo sigue sosteniendo hideTimer).
    property bool active: false
    property int hideAnimDuration: 160

    signal closeRequested

    anchors.fill: parent
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.98

    Behavior on opacity {
        NumberAnimation {
            duration: root.hideAnimDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        SpringAnimation {
            spring: Appearance.motion.springSoft.spring
            damping: Appearance.motion.springSoft.damping
            mass: Appearance.motion.springSoft.mass
            epsilon: Appearance.motion.springSoft.epsilon
        }
    }

    focus: active

    // --- Estado de navegación ---
    /// Categoría activa en la barra lateral. Se guarda por nombre para
    /// sobrevivir a los reordenamientos que provoca la búsqueda.
    property string selectedCategory: ""
    /// Índice de la fila resaltada dentro de la categoría activa.

    property int activeBindIndex: 0

    Keys.onPressed: event => {
        // El buscador tiene prioridad: si tiene el foco, sus Keys.onPressed
        // ya ha gestionado (o dejado pasar) el evento. Evita que ↑/← se
        // procesen dos veces al burbujear hasta la raíz.
        if (searchField.activeFocus)
            return;

        if (root.handleKey(event, false)) {
            event.accepted = true;
            return;
        }

        // Escribiendo con el foco fuera del buscador (p. ej. tras clicar el
        // fondo): reinyecta el carácter en vez de perderlo.
        if (event.text.length > 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier
                                                          | Qt.MetaModifier))) {
            searchField.text += event.text;
            searchField.cursorPosition = searchField.text.length;
            searchField.forceActiveFocus();
            event.accepted = true;
        }
    }

    // Swallow clicks so they don't fall through to the scrim's dismiss handler
    MouseArea {
        anchors.fill: parent
        onClicked: root.forceActiveFocus()
    }

    // ----------------------------------------------------------------
    // Navegación
    // ----------------------------------------------------------------
    NumberAnimation {
        id: scrollAnim

        target: contentFlick
        property: "contentY"
        duration: 180
        easing.type: Easing.OutCubic
    }

    function scrollTo(y) {
        const maxY = Math.max(0, contentFlick.contentHeight - contentFlick.height);
        scrollAnim.stop();
        scrollAnim.to = Math.max(0, Math.min(maxY, y));
        scrollAnim.start();
    }

    function scrollBy(delta) {
        root.scrollTo(contentFlick.contentY + delta);
    }

    function selectCategory(category) {
        if (category === root.selectedCategory)
            return;
        root.selectedCategory = category;
    }

    /// Cambia de pestaña. `wrap` permite que Tab salte de la última a la
    /// primera; las flechas se quedan en los extremos.
    function moveCategory(delta, wrap) {
        const cats = root.filteredCategories;
        if (cats.length === 0)
            return;

        let current = root.selectedIndex;
        if (current < 0)
            current = 0;

        let target = current + delta;
        if (wrap) {
            target = (target + cats.length) % cats.length;
        } else {
            target = Math.max(0, Math.min(cats.length - 1, target));
        }

        if (target === current)
            return;

        root.goToCategoryIndex(target, 0);
    }

    /// Activa la categoría `index` y coloca la selección en `bindIndex`
    /// (-1 = última fila). Se usa al cruzar de categoría con ↑/↓.
    function goToCategoryIndex(index, bindIndex) {
        const cats = root.filteredCategories;
        if (index < 0 || index >= cats.length)
            return;

        const entry = cats[index];
        const count = entry.binds.length;

        root.selectedCategory = entry.category;
        root.activeBindIndex = bindIndex < 0 ? Math.max(0, count - 1) : Math.max(0, Math.min(bindIndex, count
                                                                                             - 1));
        Qt.callLater(root.scrollToActiveItem);
    }

    /// Mueve la selección por las filas de la categoría activa. Al llegar
    /// arriba/abajo del todo, salta a la categoría anterior/siguiente para
    /// que la navegación sea continua.
    function moveSelection(delta) {
        const binds = root.selectedBinds;
        if (binds.length === 0) {
            root.moveCategory(delta, false);
            return;
        }

        const next = root.activeBindIndex + delta;
        if (next < 0) {
            if (root.selectedIndex > 0) {
                root.goToCategoryIndex(root.selectedIndex - 1, -1);
            } else {
                root.activeBindIndex = 0;
                root.scrollToActiveItem();
            }
        } else if (next >= binds.length) {
            if (root.selectedIndex >= 0 && root.selectedIndex < root.filteredCategories.length - 1) {
                root.goToCategoryIndex(root.selectedIndex + 1, 0);
            } else {
                root.activeBindIndex = binds.length - 1;
                root.scrollToActiveItem();
            }
        } else {
            root.activeBindIndex = next;
            root.scrollToActiveItem();
        }
    }

    /// Desplaza el listado justo lo necesario para que la fila activa se vea
    /// entera, usando las coordenadas reales del delegate (no estimaciones).
    function scrollToActiveItem() {
        if (root.activeBindIndex < 0 || root.selectedBinds.length === 0)
            return;

        const row = rowsRepeater.itemAt(root.activeBindIndex);
        if (!row || !contentFlick.contentItem)
            return;

        const p = row.mapToItem(contentFlick.contentItem, 0, 0);
        const viewTop = contentFlick.contentY;
        const viewBottom = viewTop + contentFlick.height;
        if (p.y < viewTop - 1) {
            root.scrollTo(p.y - 8);
        } else if (p.y + row.height > viewBottom + 1) {
            root.scrollTo(p.y + row.height - contentFlick.height + 8);
        }
    }

    /// Mantiene visible la pestaña de la categoría activa en la barra
    /// lateral cuando hay más categorías de las que caben.
    function ensureCategoryVisible() {
        if (root.selectedIndex < 0)
            return;

        const tab = tabsRepeater.itemAt(root.selectedIndex);
        if (!tab || !categoriesFlick.contentItem)
            return;

        const p = tab.mapToItem(categoriesFlick.contentItem, 0, 0);
        const viewTop = categoriesFlick.contentY;
        const viewBottom = viewTop + categoriesFlick.height;
        if (p.y < viewTop) {
            categoriesFlick.contentY = Math.max(0, p.y - 4);
        } else if (p.y + tab.height > viewBottom) {
            categoriesFlick.contentY = p.y + tab.height - categoriesFlick.height + 4;
        }
    }

    // Reseteo al abrir (llamado desde onActiveChanged del root y
    // desde onLoaded del Loader en la primera apertura).
    function resetOnOpen() {
        searchField.text = "";
        root.activeBindIndex = 0;
        root.selectedCategory = root.filteredCategories.length > 0 ? root.filteredCategories[0].category : "";
        scrollAnim.stop();
        contentFlick.contentY = 0;
        Qt.callLater(() => {
            searchField.forceActiveFocus();
            root.scrollToActiveItem();
        });
    }

    /// Gestión central de teclas para la raíz y el buscador.
    /// `fromSearch` evita secuestrar ←/→/Home/End mientras se edita texto.
    function handleKey(event, fromSearch) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;

        if (ctrl) {
            switch (event.key) {
            case Qt.Key_J:
            case Qt.Key_N:
                root.moveSelection(1);
                return true;
            case Qt.Key_K:
            case Qt.Key_P:
                root.moveSelection(-1);
                return true;
            case Qt.Key_H:
                root.moveCategory(-1, false);
                return true;
            case Qt.Key_L:
                root.moveCategory(1, false);
                return true;
            case Qt.Key_U:
                searchField.text = "";
                return true;
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
                root.closeRequested();
            }
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            root.moveCategory((event.key === Qt.Key_Backtab || shift !== 0) ? -1 : 1, true);
            return true;
        case Qt.Key_Down:
            root.moveSelection(1);
            return true;
        case Qt.Key_Up:
            root.moveSelection(-1);
            return true;
        case Qt.Key_Right:
            if (fromSearch)
                return false;
            root.moveCategory(1, false);
            return true;
        case Qt.Key_Left:
            if (fromSearch)
                return false;
            root.moveCategory(-1, false);
            return true;
        case Qt.Key_PageDown:
            root.scrollBy(contentFlick.height * 0.9);
            return true;
        case Qt.Key_PageUp:
            root.scrollBy(-contentFlick.height * 0.9);
            return true;
        case Qt.Key_Home:
            if (fromSearch && !ctrl)
                return false;
            root.activeBindIndex = 0;
            root.scrollToActiveItem();
            return true;
        case Qt.Key_End:
            if (fromSearch && !ctrl)
                return false;
            root.activeBindIndex = Math.max(0, root.selectedBinds.length - 1);
            root.scrollToActiveItem();
            return true;
        default:
            return false;
        }
    }

    // ----------------------------------------------------------------
    // Panel principal
    // ----------------------------------------------------------------
    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(root.width - 96, 1180)
        height: Math.min(root.height - 96, 780)
        radius: Appearance.shape.huge
        color: Appearance.md3.surface_container_low
        border.width: Appearance.border.width
        border.color: Appearance.border.subtleOn(Appearance.md3.surface_container_low)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.spacing.extraLarge
            spacing: Appearance.spacing.large

            // --- Cabecera: título + resumen + búsqueda + cerrar ---
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.medium

                Rectangle {
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: Appearance.shape.full
                    color: Appearance.md3.primary_container

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "keyboard"
                        size: 22
                        color: Appearance.md3.on_primary_container
                    }
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: Services.I18nService.getTranslation("cheatsheet.title", "Atajos de teclado")
                        color: Appearance.md3.on_surface
                        font.pixelSize: Appearance.typeScale.titleLarge
                        font.variableAxes: Appearance.font.variableAxes.title
                    }

                    StyledText {
                        text: Services.I18nService.getTranslation("cheatsheet.summary",
                                                                  "%1 categorías · %2 atajos").arg(
                                  root.totalCategories).arg(root.totalBinds)
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: Appearance.typeScale.labelMedium
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // --- Buscador: pill con fondo explícito + icono de lupa ---
                Item {
                    id: searchWrapper

                    Layout.preferredWidth: 340
                    Layout.minimumWidth: 200
                    implicitHeight: 48

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.shape.full
                        color: Appearance.md3.surface_container_high
                        border.width: searchField.activeFocus ? Appearance.border.focusWidth :
                                                                Appearance.border.width
                        border.color: searchField.activeFocus ? Appearance.border.focus :
                                                                Appearance.border.color

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }

                    MaterialIcon {
                        id: searchIcon

                        anchors {
                            left: parent.left
                            leftMargin: Appearance.spacing.large
                            verticalCenter: parent.verticalCenter
                        }

                        icon: "search"
                        size: Appearance.font.pixelSize.large
                        color: searchField.activeFocus ? Appearance.md3.primary :
                                                         Appearance.md3.on_surface_variant

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
                            leftMargin: Appearance.spacing.small
                            rightMargin: 20
                        }

                        Accessible.name: placeholderText
                        background: null
                        color: Appearance.md3.on_surface
                        placeholderText: Services.I18nService.getTranslation("cheatsheet.search_placeholder",
                                                                             "Buscar atajos de teclado…")
                        placeholderTextColor: Appearance.md3.on_surface_variant
                        // Gatillado a active: sin esto el campo retenía el foco durante
                        // el fade-out (active=false, ventana aún visible) y Qt pedía
                        // text-input en una surface sin foco Wayland (spam
                        // enable/disableSurface). El foco real lo da resetOnOpen().
                        focus: root.active
                        selectedTextColor: Appearance.md3.on_secondary_container
                        selectionColor: Appearance.md3.secondary_container
                        font.family: Appearance.font.sans
                        font.pixelSize: Appearance.typeScale.bodyLarge
                        font.variableAxes: Appearance.font.variableAxes.main
                        verticalAlignment: TextInput.AlignVCenter

                        Keys.onPressed: event => {
                            if (root.handleKey(event, true))
                                event.accepted = true;
                        }
                    }
                }

                AnimatedIconButton {
                    icon: "close"
                    iconSize: 20
                    onClicked: root.closeRequested()
                }
            }

            // --- Cuerpo: pestañas a la izquierda, atajos a la derecha ---
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Appearance.spacing.large
                visible: root.filteredCategories.length > 0

                // Barra lateral de categorías
                Rectangle {
                    Layout.preferredWidth: 236
                    Layout.minimumWidth: 180
                    Layout.maximumWidth: 260
                    Layout.fillHeight: true
                    radius: Appearance.shape.extraLarge
                    color: Appearance.md3.surface_container
                    border.width: Appearance.border.width
                    border.color: Appearance.border.subtleOn(Appearance.md3.surface_container)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.spacing.small
                        spacing: Appearance.spacing.extraSmall

                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Appearance.spacing.small
                            Layout.topMargin: Appearance.spacing.extraSmall
                            text: Services.I18nService.getTranslation("cheatsheet.categories", "Categorías")
                            color: Appearance.md3.on_surface_variant
                            font.pixelSize: Appearance.typeScale.labelMedium
                            font.variableAxes: Appearance.font.variableAxes.title
                        }

                        Flickable {
                            id: categoriesFlick

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: tabsColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: StyledScrollBar {}

                            ColumnLayout {
                                id: tabsColumn

                                width: parent.width
                                spacing: 2

                                Repeater {
                                    id: tabsRepeater

                                    model: root.filteredCategories

                                    delegate: CheatsheetCategoryTab {
                                        required property var modelData
                                        required property int index

                                        category: modelData.category
                                        icon: root.iconForCategory(modelData.category)
                                        count: modelData.binds.length
                                        selected: modelData.category === root.selectedCategory
                                        onClicked: {
                                            root.selectCategory(modelData.category);
                                            // Al clicar una pestaña, las flechas
                                            // vuelven a navegar el menú; si el
                                            // usuario escribe, el texto se
                                            // reinyecta en el buscador.
                                            root.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Panel de atajos de la categoría activa
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.shape.extraLarge
                    color: Appearance.md3.surface_container_lowest
                    border.width: Appearance.border.width
                    border.color: Appearance.border.subtleOn(Appearance.md3.surface_container_lowest)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.spacing.large
                        spacing: Appearance.spacing.medium

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: root.selectedEntry ? root.selectedEntry.category : ""
                                color: Appearance.md3.on_surface
                                font.pixelSize: Appearance.typeScale.headlineSmall
                                font.variableAxes: Appearance.font.variableAxes.title
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                implicitWidth: countLabel.implicitWidth + 16
                                implicitHeight: 24
                                radius: Appearance.shape.full
                                color: Appearance.md3.surface_container_high

                                StyledText {
                                    id: countLabel

                                    anchors.centerIn: parent
                                    text: Services.I18nService.getTranslation("cheatsheet.bind_count",
                                                                              "%1 atajos").arg(
                                              root.selectedBinds.length)
                                    color: Appearance.md3.on_surface_variant
                                    font.pixelSize: Appearance.typeScale.labelMedium
                                    font.variableAxes: Appearance.font.variableAxes.numbers
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Appearance.border.divider
                        }

                        Flickable {
                            id: contentFlick

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: rowsColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: StyledScrollBar {}

                            Column {
                                id: rowsColumn

                                width: parent.width
                                spacing: 2

                                Repeater {
                                    id: rowsRepeater

                                    model: root.selectedBinds
                                    delegate: CheatsheetKeybindRow {
                                        required property var modelData
                                        required property int index

                                        width: rowsColumn.width
                                        bind: modelData
                                        highlighted: index === root.activeBindIndex
                                        onHoverEntered: root.activeBindIndex = index
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- Estado vacío ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.filteredCategories.length === 0

                M3Card {
                    anchors.centerIn: parent
                    width: emptyContent.implicitWidth + 56
                    height: emptyContent.implicitHeight + 48

                    EmptyState {
                        id: emptyContent

                        icon: searchField.text.length > 0 ? "search_off" : (Services.HyprlandKeybinds.failed
                                                                            ? "error" : "keyboard")
                        iconSize: 52
                        iconOpacity: 0.55
                        iconColor: Services.HyprlandKeybinds.failed && searchField.text.length === 0
                                   ? Appearance.md3.error : Appearance.md3.on_surface_variant
                        titleSize: Appearance.typeScale.bodyLarge
                        title: searchField.text.length > 0 ? Services.I18nService.getTranslation(
                                                                 "cheatsheet.empty_no_match",
                                                                 "Ningún atajo coincide con") + " \u201c"
                                                             + searchField.text + "\u201d" : (
                                                                 Services.HyprlandKeybinds.failed
                                                                 ? Services.I18nService.getTranslation(
                                                                       "cheatsheet.empty_error",
                                                                       "No se pudieron leer los atajos (¿hyprctl disponible?)") :
                                                                   Services.I18nService.getTranslation(
                                                                       "cheatsheet.empty_no_binds",
                                                                       "No se encontraron atajos documentados"))
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Services.I18nService.getTranslation("cheatsheet.hint",
                                                          "↑/↓ mover · Ctrl+H/L o Tab categorías · Esc limpiar/cerrar")
                color: Appearance.md3.on_surface_variant
                font.pixelSize: Appearance.typeScale.labelMedium
                opacity: Appearance.opacity.hintStrong
            }
        }
    }

    // ----------------------------------------------------------------
    // Datos derivados
    // ----------------------------------------------------------------
    readonly property int totalCategories: root.filteredCategories.length

    readonly property int totalBinds: {
        let total = 0;
        for (let i = 0; i < root.filteredCategories.length; i++)
            total += root.filteredCategories[i].binds.length;
        return total;
    }

    readonly property int selectedIndex: {
        for (let i = 0; i < root.filteredCategories.length; i++) {
            if (root.filteredCategories[i].category === root.selectedCategory)
                return i;
        }
        return -1;
    }

    readonly property var selectedEntry: root.selectedIndex >= 0 ? root.filteredCategories[root.selectedIndex] :
                                                                   null

    readonly property var selectedBinds: root.selectedEntry ? root.selectedEntry.binds : []

    /// Icono Material de cada categoría conocida; "keyboard" para el resto.
    function iconForCategory(category) {
        switch (category) {
        case "Ventanas":
            return "window";
        case "Scrolling":
            return "swap_vert";
        case "Espacios":
            return "space_dashboard";
        case "Apps":
            return "apps";
        case "Sistema":
            return "settings";
        case "Multimedia":
            return "music_note";
        case "Redimensionar":
            return "aspect_ratio";
        case "Submapas":
            return "layers";
        default:
            return "keyboard";
        }
    }

    // --- Filtering ---
    // Usa Services.FuzzySearch (subsecuencia + scoring). Mientras hay query,
    // las categorías sin coincidencias desaparecen de la barra lateral y la
    // que mejor puntúa queda seleccionada.
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
                                binds: matches.map(m => m.item),
                                score: matches[0].score
                            });
        }

        if (query.length > 0)
            result.sort((a, b) => b.score - a.score);

        return result;
    }

    onFilteredCategoriesChanged: {
        // Mientras se escribe, salta siempre a la categoría con mejor
        // puntuación (la primera tras ordenar). Sin búsqueda se conserva
        // la pestaña activa si sigue existiendo.
        const searching = searchField.text.trim().length > 0;
        let found = false;
        for (let i = 0; i < root.filteredCategories.length; i++) {
            if (root.filteredCategories[i].category === root.selectedCategory) {
                found = true;
                break;
            }
        }
        if (searching || !found) {
            root.selectedCategory = root.filteredCategories.length > 0 ? root.filteredCategories[0].category :
                                                                         "";
        }

        root.activeBindIndex = 0;
        scrollAnim.stop();
        contentFlick.contentY = 0;
        Qt.callLater(root.scrollToActiveItem);
        Qt.callLater(root.ensureCategoryVisible);
    }

    onSelectedCategoryChanged: {
        root.activeBindIndex = 0;
        scrollAnim.stop();
        contentFlick.contentY = 0;
        Qt.callLater(root.scrollToActiveItem);
        Qt.callLater(root.ensureCategoryVisible);
    }
}
