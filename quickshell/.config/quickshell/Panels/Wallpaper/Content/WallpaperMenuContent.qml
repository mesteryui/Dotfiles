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
    // Grupo de color seleccionado (-1 = todos). Selección única, como Ryoku.
    property int colorFilter: -1
    // Resultado filtrado que alimenta el ListView (array de { filePath, name }).
    property var filtered: []
    // Texto de búsqueda (alias bidireccional al campo real).
    property alias query: searchField.text
    readonly property bool filtersActive: typeFilter !== "all" || colorFilter !== -1 || query !== ""
    // Cambió un filtro (tipo/color/búsqueda): la próxima reconstrucción
    // vuelve al primer resultado en vez de conservar la selección.
    property bool resetSelection: false

    signal hideRequested

    function requestFocus() {
        wallpaperList.forceActiveFocus();
    }

    function label(key: string, fallback: string): string {
        return Services.I18nService?.getTranslation(key, fallback) ?? fallback;
    }

    // Selección única (como Ryoku): pulsar el grupo activo lo desactiva.
    function toggleColor(group: int): void {
        root.colorFilter = (root.colorFilter === group) ? -1 : group;
    }

    function clearColor(): void {
        root.colorFilter = -1;
    }

    function clearFilters(): void {
        root.typeFilter = "all";
        root.colorFilter = -1;
        root.query = "";
    }

    // Devuelve true si consumió el Escape (limpió algún filtro); false si no
    // quedaba nada por limpiar y el menú puede cerrarse.
    function escapePressed(): bool {
        if (root.query !== "") {
            root.query = "";
            return true;
        }
        if (root.typeFilter !== "all" || root.colorFilter !== -1) {
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
    // cambios por fila, así que se rehace al vuelo. Al cambiar un filtro la
    // selección vuelve al primer resultado; en el resto de reconstrucciones
    // (nuevos fondos, escaneo de color) se conserva por ruta.
    function rebuildModel(): void {
        const source = Services.WallpaperService.wallpaperList;
        const colorService = Services.WallpaperColorService;
        const hasColorFilter = root.colorFilter !== -1;
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
            const group = colorService.groupFor(path);
            if (hasColorFilter && group !== root.colorFilter)
                continue;
            const name = String(source.get(i, "fileName") ?? "");
            entries.push({
                "filePath": path,
                "name": name,
                "group": group,
                "sat": colorService.satFor(path)
            });
        }
        if (root.query.trim() !== "")
            entries = Services.FuzzySearch.filterItems(root.query, entries, entry => entry.name);

        // Orden por color, como Ryoku: grupos en orden arcoíris (neutro al
        // final) y, dentro del grupo, el más saturado primero. Así el
        // carrusel "lee" como un arcoíris aunque no haya filtro activo.
        const neutral = colorService.neutral;
        const rank = g => (g < 0 ? 101 : (g === neutral ? 100 : g));
        entries.sort((a, b) => {
            const ga = rank(a.group);
            const gb = rank(b.group);
            if (ga !== gb)
                return ga - gb;
            return b.sat - a.sat;
        });

        // Selección: tras un cambio de filtro, el primer resultado; si no,
        // se conserva el fondo actual mientras siga en el resultado y, si
        // no, la posición anterior recortada al nuevo tamaño.
        let index = -1;
        if (root.resetSelection) {
            root.resetSelection = false;
            if (entries.length > 0)
                index = 0;
        } else if (previousPath !== "") {
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

    onTypeFilterChanged: {
        root.resetSelection = true;
        rebuildTimer.restart();
    }
    onColorFilterChanged: {
        root.resetSelection = true;
        rebuildTimer.restart();
    }
    onQueryChanged: {
        root.resetSelection = true;
        rebuildTimer.restart();
    }

    // Diferir la reconstrucción: coalescea ráfagas (cada tecla de búsqueda,
    // llegada de colores + cambio de carpeta a la vez). 120 ms es suficiente
    // para que se sienta instantáneo sin saturar la CPU al escribir.
    Timer {
        id: rebuildTimer
        interval: 120
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
        spacing: Appearance.spacing.large

        // ── Cabecera ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: Appearance.spacing.medium

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
                radius: Appearance.shape.medium
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
                spacing: Appearance.spacing.small

                Rectangle {
                    color: Qt.alpha(Appearance.md3.on_surface, 0.06)
                    radius: Appearance.shape.small
                    implicitWidth: hint1.implicitWidth + 12
                    implicitHeight: 22
                    border.color: Appearance.border.subtleOn(Appearance.md3.surface)
                    border.width: Appearance.border.width

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
                    radius: Appearance.shape.small
                    implicitWidth: hint2.implicitWidth + 12
                    implicitHeight: 22
                    border.color: Appearance.border.subtleOn(Appearance.md3.surface)
                    border.width: Appearance.border.width

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
                    anchors.leftMargin: Appearance.spacing.large
                    anchors.rightMargin: Appearance.spacing.small
                    spacing: Appearance.spacing.small

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
                        icon: "close"
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
                spacing: Appearance.spacing.extraLarge // positivo: evita que las tarjetas se pisen entre sí
                clip: false
                focus: true

                pixelAligned: true
                // Buffer de carrusel reducido: ~2 tarjetas por lado. Suficiente
                // para el scroll animado sin retener delegados de más (menos
                // memoria, menos decodados de frames de vídeo simultáneos).
                cacheBuffer: 400
                snapMode: ListView.SnapToItem
                highlightMoveDuration: 180 // más rápido, sin easing pesado
                highlightFollowsCurrentItem: true

                // Centrado estricto tipo Carrusel / Coverflow
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width / 2) - 150
                preferredHighlightEnd: (width / 2) + 150

                boundsBehavior: Flickable.StopAtBounds

                // Relleno invisible a ambos lados: sin esto, el primer y el
                // último fondo nunca pueden centrarse (el contentX no puede
                // pasar de los bordes) y queda ese hueco vacío/asimétrico.
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

                // Navegación por teclado (ciclo infinito)
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
                icon: "image_not_supported"
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
