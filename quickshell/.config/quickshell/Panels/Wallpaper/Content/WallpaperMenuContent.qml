pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Panels.Wallpaper
import qs.Primitives
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // ── Estado de filtros ───────────────────────────────────────────────
    // Tipo: "all" | "image" | "video".
    property string typeFilter: "all"
    // Tono -> true. Multi-selección: se muestran los fondos de CUALQUIER
    // tono marcado (unión), no la intersección.
    property var toneFilter: ({})
    // Resultado filtrado que alimenta el ListView (array de { filePath, name }).
    property var filtered: []
    // Texto de búsqueda (alias bidireccional al campo real).
    property alias query: searchField.text
    readonly property int toneFilterCount: Object.keys(toneFilter).length
    readonly property bool filtersActive: typeFilter !== "all" || toneFilterCount > 0 || query !== ""

    signal hideRequested

    function requestFocus() {
        wallpaperList.forceActiveFocus();
    }

    function label(key: string, fallback: string): string {
        return Services.I18nService?.getTranslation(key, fallback) ?? fallback;
    }

    function toggleTone(tone: string): void {
        // Objeto nuevo (no mutación): los bindings/onToneFilterChanged solo
        // reaccionan a la reasignación.
        const next = {};
        for (const key in root.toneFilter) {
            if (root.toneFilter[key])
                next[key] = true;
        }
        if (next[tone])
            delete next[tone];
        else
            next[tone] = true;
        root.toneFilter = next;
    }

    function clearFilters(): void {
        root.typeFilter = "all";
        root.toneFilter = ({});
        root.query = "";
    }

    // Devuelve true si consumió el Escape (limpió algún filtro); false si no
    // quedaba nada por limpiar y el menú puede cerrarse.
    function escapePressed(): bool {
        if (root.query !== "") {
            root.query = "";
            return true;
        }
        if (root.typeFilter !== "all" || root.toneFilterCount > 0) {
            root.clearFilters();
            return true;
        }
        return false;
    }

    function applyCurrentWallpaper(): void {
        const index = wallpaperList.currentIndex;
        if (index < 0 || index >= root.filtered.length)
            return;
        const path = String(root.filtered[index].filePath || "");
        if (path === "")
            return;
        Services.WallpaperService.apply(path);
        root.hideRequested();
    }

    // ¿La tecla es texto escribible sin modificadores? Sirve para llevar al
    // buscador cuando el carrusel tiene el foco (escribir no navega).
    function isTypingKey(event): bool {
        if (!event.text || event.text.length !== 1)
            return false;
        if (event.text.charCodeAt(0) < 0x20)
            return false;
        return (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0;
    }

    // Reconstruye la lista filtrada a partir del FolderListModel del
    // servicio. Imperativo (no binding): el FolderListModel no notifica
    // cambios por fila, así que se rehace al vuelo y se conserva la
    // selección por ruta cuando sigue pasando el filtro.
    function rebuildModel(): void {
        const source = Services.WallpaperService.wallpaperList;
        const colorService = Services.WallpaperColorService;
        const hasToneFilter = root.toneFilterCount > 0;
        const previousIndex = wallpaperList.currentIndex;
        // Ruta del fondo seleccionado ANTES de rehacer la lista (desde el
        // modelo actual, no desde el delegado: el delegado puede reciclarse).
        const previousValid = previousIndex >= 0 && previousIndex < root.filtered.length;
        const previousPath = previousValid ? String(root.filtered[previousIndex].filePath || "") : "";

        let entries = [];
        for (let i = 0; i < source.count; i++) {
            const path = String(source.get(i, "filePath") ?? "");
            if (path === "")
                continue;
            const isVideo = Services.WallpaperService.isVideo(path);
            if (root.typeFilter === "image" && isVideo)
                continue;
            if (root.typeFilter === "video" && !isVideo)
                continue;
            if (hasToneFilter && !root.toneFilter[colorService.toneFor(path)])
                continue;
            const name = String(source.get(i, "fileName") ?? "");
            entries.push({
                             "filePath": path,
                             "name": name
                         });
        }
        if (root.query.trim() !== "")
            entries = Services.FuzzySearch.filterItems(root.query, entries, entry => entry.name);

        // Selección: se conserva el fondo actual si sigue en el resultado;
        // si no, la posición anterior recortada al nuevo tamaño.
        let index = -1;
        if (previousPath !== "") {
            for (let i = 0; i < entries.length; i++) {
                if (String(entries[i].filePath) === previousPath) {
                    index = i;
                    break;
                }
            }
        }
        if (index < 0 && entries.length > 0)
            index = Math.min(Math.max(previousIndex, 0), entries.length - 1);
        root.filtered = entries;
        wallpaperList.currentIndex = Math.max(index, 0);
    }

    // Sonda lazy de vídeo: el menú lista vídeos (filtros según soporte),
    // así que abrirlo sí justifica cargar QtMultimedia. El arranque no.
    // El escaneo de color es idempotente y barato con la caché vigente.
    Component.onCompleted: {
        Services.VideoSupport.ensureProbed();
        Services.WallpaperColorService.ensureScan();
        root.rebuildModel();
    }

    onTypeFilterChanged: rebuildTimer.restart()
    onToneFilterChanged: rebuildTimer.restart()
    onQueryChanged: rebuildTimer.restart()

    // Diferir la reconstrucción: coalescea ráfagas (cada tecla de búsqueda,
    // llegada de colores + cambio de carpeta a la vez).
    Timer {
        id: rebuildTimer

        interval: 80
        repeat: false
        onTriggered: root.rebuildModel()
    }

    Connections {
        function onCountChanged() {
            rebuildTimer.restart();
        }

        target: Services.WallpaperService.wallpaperList
    }

    Connections {
        function onColorsChanged() {
            rebuildTimer.restart();
        }

        target: Services.WallpaperColorService
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── Cabecera ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: Appearance.spacing.m

            StyledText {
                text: root.label("wallpaper.title", "Fondos de Pantalla")
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Bold
                font.family: Appearance.font.sans
                color: Appearance.md3.on_surface
                verticalAlignment: Text.AlignVCenter
            }

            // Contador de elementos (del resultado filtrado)
            Rectangle {
                color: Appearance.md3.surface_container_high
                radius: Appearance.shape.small
                implicitWidth: countText.implicitWidth + 16
                implicitHeight: 24

                StyledText {
                    id: countText

                    anchors.centerIn: parent
                    text: (wallpaperList.count > 0 ? wallpaperList.currentIndex + 1 : 0) + " / "
                          + wallpaperList.count
                    font.pixelSize: Appearance.typeScale.labelSmall
                    font.weight: Font.Medium
                    color: Appearance.md3.primary
                }
            }

            // Píldoras de ayuda rápida de teclado
            Row {
                spacing: 6

                Rectangle {
                    color: Qt.alpha(Appearance.md3.on_surface, 0.06)
                    radius: Appearance.shape.unsharpenmore
                    implicitWidth: hint1.implicitWidth + 12
                    implicitHeight: 22
                    border.color: Qt.alpha(Appearance.md3.on_surface, 0.1)
                    border.width: 1

                    StyledText {
                        id: hint1

                        anchors.centerIn: parent
                        text: root.label("wallpaper.hint_navigate", "← → Navegar")
                        font.pixelSize: Appearance.typeScale.labelSmall
                        color: Appearance.md3.on_surface_variant
                    }
                }

                Rectangle {
                    color: Qt.alpha(Appearance.md3.on_surface, 0.06)
                    radius: Appearance.shape.unsharpenmore
                    implicitWidth: hint2.implicitWidth + 12
                    implicitHeight: 22
                    border.color: Qt.alpha(Appearance.md3.on_surface, 0.1)
                    border.width: 1

                    StyledText {
                        id: hint2

                        anchors.centerIn: parent
                        text: root.label("wallpaper.hint_apply", "↵ Aplicar")
                        font.pixelSize: Appearance.typeScale.labelSmall
                        color: Appearance.md3.on_surface_variant
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // ── Buscador por nombre ─────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 300
                Layout.preferredHeight: 40
                radius: Appearance.shape.full
                color: Appearance.md3.surface_container_high

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 6
                    spacing: 6

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        icon: "search"
                        size: Appearance.typeScale.bodyLarge
                        color: Appearance.md3.on_surface_variant
                    }

                    MaterialTextField {
                        id: searchField

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        background: Rectangle {
                            color: "transparent"
                        }
                        placeholderText: root.label("wallpaper.search", "Buscar fondos…")
                        placeholderTextColor: Appearance.md3.on_surface_variant
                        verticalAlignment: TextInput.AlignVCenter
                        selectedTextColor: Appearance.md3.on_primary
                        selectionColor: Appearance.md3.primary
                        Accessible.name: searchField.placeholderText

                        // Abajo entra al carrusel; Intro aplica el resultado
                        // actual (el primero si acabas de buscar).
                        Keys.onDownPressed: wallpaperList.forceActiveFocus()
                        Keys.onReturnPressed: root.applyCurrentWallpaper()
                        Keys.onEnterPressed: root.applyCurrentWallpaper()
                    }

                    ButtonIcon {
                        Layout.alignment: Qt.AlignVCenter
                        iconName: "close"
                        iconSize: 18
                        iconColor: Appearance.md3.on_surface_variant
                        visible: searchField.text !== ""
                        onClicked: {
                            searchField.text = "";
                            searchField.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // ── Filtros (tipo + color) ──────────────────────────────────────
        WallpaperFilterBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            host: root
        }

        // ── Carrusel / Coverflow ListView ────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: wallpaperList

                anchors.fill: parent
                model: root.filtered
                orientation: ListView.Horizontal
                spacing: 20 // positivo: evita que las tarjetas se pisen entre sí
                clip: false
                focus: true

                pixelAligned: true
                // Buffer de carrusel: ~2-3 tarjetas por lado (antes 1200).
                // Suficiente para el scroll animado (300ms) sin retener
                // de más; si notas recarga al hacer flick rápido, subir.
                cacheBuffer: 800
                snapMode: ListView.SnapToItem
                highlightMoveDuration: 300
                highlightFollowsCurrentItem: true

                // Centrado estricto tipo Carrusel / Coverflow
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width / 2) - 150
                preferredHighlightEnd: (width / 2) + 150

                boundsBehavior: Flickable.StopAtBounds

                // Relleno invisible a ambos lados: sin esto, el primer y el
                // último fondo nunca pueden centrarse (el contentX no puede
                // pasar de los bordes) y queda ese hueco vacío/asimétrico.
                // El ancho coincide con el mismo cálculo del highlightRange
                // (150 = mitad del ancho de tarjeta) para que quede simétrico.
                header: Item {
                    width: Math.max(0, wallpaperList.width / 2 - 150)
                    height: 1
                }
                footer: Item {
                    width: Math.max(0, wallpaperList.width / 2 - 150)
                    height: 1
                }

                // Desplazamiento por rueda de ratón / touchpad
                WheelHandler {
                    id: wheelHandler

                    orientation: Qt.Horizontal | Qt.Vertical
                    onWheel: event => {
                        if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                            wallpaperList.incrementCurrentIndex();
                        } else if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                            wallpaperList.decrementCurrentIndex();
                        }
                    }
                }

                // Navegación por teclado
                Keys.onLeftPressed: {
                    currentIndex === 0 ? currentIndex = wallpaperList.count - 1 : decrementCurrentIndex();
                }

                Keys.onRightPressed: {
                    currentIndex === wallpaperList.count - 1 ? currentIndex = 0 : incrementCurrentIndex();
                }

                Keys.onReturnPressed: root.applyCurrentWallpaper()

                // Escribir (o borrar) con el carrusel enfocado lleva al
                // buscador: el filtro es accesible sin tocar el ratón.
                Keys.onPressed: event => {
                    if (root.isTypingKey(event)) {
                        searchField.forceActiveFocus();
                        searchField.text += event.text;
                        searchField.cursorPosition = searchField.text.length;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backspace && root.query !== "") {
                        searchField.forceActiveFocus();
                        searchField.text = root.query.slice(0, -1);
                        searchField.cursorPosition = searchField.text.length;
                        event.accepted = true;
                    }
                }

                delegate: WallpaperItem {
                    onClicked: {
                        wallpaperList.currentIndex = index;
                        root.applyCurrentWallpaper();
                    }
                }
            }

            // Estado vacío: carpeta sin fondos, o filtros sin resultados.
            EmptyState {
                anchors.centerIn: parent
                visible: root.filtered.length === 0
                iconName: "image_not_supported"
                title: root.filtersActive ? root.label("wallpaper.no_match", "Ningún fondo coincide") :
                                            root.label("wallpaper.no_results", "No se encontraron fondos")
                subtitle: root.filtersActive ? root.label("wallpaper.no_match_hint",
                                                          "Prueba a quitar algún filtro") : ""
                actionVisible: root.filtersActive
                actionText: root.label("wallpaper.filter.clear", "Limpiar")
                onActionClicked: root.clearFilters()
            }
        }
    }
}
