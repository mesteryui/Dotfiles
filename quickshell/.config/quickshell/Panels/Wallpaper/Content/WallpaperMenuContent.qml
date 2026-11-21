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
    property string typeFilter: "all"
    property int colorFilter: -1
    property var filtered: []
    property alias query: searchField.text
    readonly property bool filtersActive: typeFilter !== "all" || colorFilter !== -1 || query !== ""
    property bool resetSelection: false

    signal hideRequested

    function requestFocus() {
        wallpaperList.forceActiveFocus();
    }

    function label(key: string, fallback: string): string {
        return Services.I18nService?.getTranslation(key, fallback) ?? fallback;
    }

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

    function escapePressed(): bool {
        if (root.query !== "") {
            root.query = "";
            wallpaperList.forceActiveFocus();
            return true;
        }
        if (root.typeFilter !== "all" || root.colorFilter !== -1) {
            root.clearFilters();
            wallpaperList.forceActiveFocus();
            return true;
        }
        if (searchField.activeFocus) {
            wallpaperList.forceActiveFocus();
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

    function isTypingKey(event): bool {
        if (!event.text || event.text.length !== 1)
            return false;
        if (event.text.charCodeAt(0) < 0x20)
            return false;
        return (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0;
    }

    function rebuildModel(): void {
        const source = Services.WallpaperService.wallpaperList;
        const colorService = Services.WallpaperColorService;
        const hasColorFilter = root.colorFilter !== -1;
        const previousIndex = wallpaperList.currentIndex;
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

        const neutral = colorService.neutral;
        const rank = g => (g < 0 ? 101 : (g === neutral ? 100 : g));
        entries.sort((a, b) => {
            const ga = rank(a.group);
            const gb = rank(b.group);
            if (ga !== gb)
                return ga - gb;
            return b.sat - a.sat;
        });

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

    // ══════════════════════════════════════════════════════════════════════
    // BARRA SUPERIOR FLOTANTE (Colores adaptados a Matugen M3)
    // ══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: topBarCard

        anchors {
            top: parent.top
            topMargin: 20
            horizontalCenter: parent.horizontalCenter
        }

        width: Math.min(parent.width - 64, 1180)
        height: 104
        radius: 16
        // Fondo adaptado a Matugen con translucidez elegante
        color: Qt.alpha(Appearance.md3.surface_container_high, 0.92)
        border.color: Qt.alpha(Appearance.md3.outline_variant, 0.35)
        border.width: 1

        Column {
            anchors.fill: parent
            spacing: 0

            // ── Fila 1: Logo + Botón Wallpapers + Buscador + Contador
            Item {
                width: parent.width
                height: 58

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 14

                    // Logo / Kanji
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: "路"
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        color: Appearance.md3.primary
                    }

                    // Botón píldora adaptado a Matugen: primary + on_primary
                    Rectangle {
                        Layout.preferredWidth: titleCol.implicitWidth + 28
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        radius: 10
                        color: Appearance.md3.primary

                        Column {
                            id: titleCol

                            anchors.centerIn: parent
                            spacing: 1

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "壁紙"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Qt.alpha(Appearance.md3.on_primary, 0.75)
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.label("wallpaper.title", "Wallpapers")
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: Appearance.md3.on_primary
                            }
                        }
                    }

                    // ── Buscador centrado ────────────────────────────────
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            MaterialIcon {
                                Layout.alignment: Qt.AlignVCenter
                                icon: "search"
                                size: 16
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
                                placeholderTextColor: Qt.alpha(Appearance.md3.on_surface_variant, 0.60)
                                color: Appearance.md3.on_surface
                                verticalAlignment: TextInput.AlignVCenter
                                selectedTextColor: Appearance.md3.on_primary
                                selectionColor: Appearance.md3.primary
                                font.pixelSize: 13
                                Accessible.name: searchField.placeholderText

                                Keys.onDownPressed: wallpaperList.forceActiveFocus()
                                Keys.onTabPressed: wallpaperList.forceActiveFocus()
                                Keys.onBacktabPressed: wallpaperList.forceActiveFocus()
                                Keys.onReturnPressed: root.applyCurrentWallpaper()
                                Keys.onEnterPressed: root.applyCurrentWallpaper()
                                Keys.onEscapePressed: {
                                    if (searchField.text !== "") {
                                        searchField.text = "";
                                    }
                                    wallpaperList.forceActiveFocus();
                                }
                                Keys.onRightPressed: event => {
                                    if (searchField.text === "" || (searchField.cursorPosition
                                                                    >= searchField.length
                                                                    && searchField.selectedText === "")) {
                                        wallpaperList.forceActiveFocus();
                                        if (wallpaperList.currentIndex === wallpaperList.count - 1)
                                            wallpaperList.currentIndex = 0;
                                        else
                                            wallpaperList.incrementCurrentIndex();
                                        event.accepted = true;
                                    }
                                }
                                Keys.onLeftPressed: event => {
                                    if (searchField.text === "" || (searchField.cursorPosition === 0
                                                                    && searchField.selectedText === "")) {
                                        wallpaperList.forceActiveFocus();
                                        if (wallpaperList.currentIndex === 0)
                                            wallpaperList.currentIndex = wallpaperList.count - 1;
                                        else
                                            wallpaperList.decrementCurrentIndex();
                                        event.accepted = true;
                                    }
                                }
                            }

                            ButtonIcon {
                                Layout.alignment: Qt.AlignVCenter
                                icon: "close"
                                iconSize: 14
                                iconColor: Appearance.md3.on_surface_variant
                                visible: searchField.text !== ""
                                onClicked: {
                                    searchField.text = "";
                                    wallpaperList.forceActiveFocus();
                                }
                            }
                        }

                        // Línea sutil horizontal debajo del input
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.alpha(Appearance.md3.outline_variant, 0.40)
                        }
                    }

                    // Contador de wallpapers traducible
                    Item {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter

                        Column {
                            anchors.centerIn: parent
                            spacing: 0

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: String(wallpaperList.count)
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                color: Appearance.md3.primary
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.label("wallpaper.walls", "WALLS")
                                font.pixelSize: 8
                                font.weight: Font.Medium
                                color: Appearance.md3.on_surface_variant
                                font.letterSpacing: 1.5
                            }
                        }
                    }
                }
            }

            // Línea divisora entre filas
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.alpha(Appearance.md3.outline_variant, 0.30)
            }

            // ── Fila 2: Filtros de tipo y color (sin botones innecesarios)
            Item {
                width: parent.width
                height: 44

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20

                    WallpaperFilterBar {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        host: root
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ÁREA CENTRAL DEL CARRUSEL (Imágenes más altas y centradas)
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: carouselArea

        anchors {
            top: topBarCard.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        property real _wheelDelta: 0

        Timer {
            id: wheelResetTimer

            interval: 200
            repeat: false
            onTriggered: carouselArea._wheelDelta = 0
        }

        // Clic en cualquier espacio vacío del carrusel transfiere el foco de teclado a la lista
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: wallpaperList.forceActiveFocus()
        }

        WheelHandler {
            id: wheelHandler

            target: carouselArea
            orientation: Qt.Horizontal | Qt.Vertical
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const deltaY = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y;
                const deltaX = event.angleDelta.x !== 0 ? event.angleDelta.x : event.pixelDelta.x;
                const delta = Math.abs(deltaY) >= Math.abs(deltaX) ? deltaY : -deltaX;

                carouselArea._wheelDelta += delta;
                wheelResetTimer.restart();
                const threshold = 60;
                if (carouselArea._wheelDelta <= -threshold) {
                    carouselArea._wheelDelta = 0;
                    if (wallpaperList.currentIndex === wallpaperList.count - 1)
                        wallpaperList.currentIndex = 0;
                    else
                        wallpaperList.incrementCurrentIndex();
                    wallpaperList.forceActiveFocus();
                } else if (carouselArea._wheelDelta >= threshold) {
                    carouselArea._wheelDelta = 0;
                    if (wallpaperList.currentIndex === 0)
                        wallpaperList.currentIndex = wallpaperList.count - 1;
                    else
                        wallpaperList.decrementCurrentIndex();
                    wallpaperList.forceActiveFocus();
                }
            }
        }

        // ── Botón flecha izquierda para ratón ──────────────────────────────
        Rectangle {
            id: leftNavBtn
            anchors {
                left: parent.left
                leftMargin: 24
                verticalCenter: wallpaperList.verticalCenter
            }

            width: 44
            height: 44
            radius: 22
            z: 30
            visible: wallpaperList.count > 1
            color: leftNavMouse.pressed ? Appearance.md3.primary : leftNavMouse.containsMouse
                                          ? Appearance.md3.surface_container_highest : Qt.alpha(
                                                Appearance.md3.surface_container_high, 0.85)
            border.color: leftNavMouse.containsMouse ? Appearance.md3.primary : Qt.alpha(
                                                           Appearance.md3.outline_variant, 0.40)
            border.width: 1
            scale: leftNavMouse.pressed ? 0.94 : (leftNavMouse.containsMouse ? 1.08 : 1.0)

            Behavior on scale {
                SpringAnimation {
                    spring: 3.5
                    damping: 0.22
                    mass: 0.6
                    epsilon: 0.005
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.motion.fast
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                icon: "chevron_left"
                size: 26
                color: leftNavMouse.pressed ? Appearance.md3.on_primary : leftNavMouse.containsMouse
                                              ? Appearance.md3.primary : Appearance.md3.on_surface
            }

            MouseArea {
                id: leftNavMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wallpaperList.currentIndex === 0)
                        wallpaperList.currentIndex = wallpaperList.count - 1;
                    else
                        wallpaperList.decrementCurrentIndex();
                    wallpaperList.forceActiveFocus();
                }
            }
        }

        // ── Botón flecha derecha para ratón ───────────────────────────────
        Rectangle {
            id: rightNavBtn
            anchors {
                right: parent.right
                rightMargin: 24
                verticalCenter: wallpaperList.verticalCenter
            }

            width: 44
            height: 44
            radius: 22
            z: 30
            visible: wallpaperList.count > 1
            color: rightNavMouse.pressed ? Appearance.md3.primary : rightNavMouse.containsMouse
                                           ? Appearance.md3.surface_container_highest : Qt.alpha(
                                                 Appearance.md3.surface_container_high, 0.85)
            border.color: rightNavMouse.containsMouse ? Appearance.md3.primary : Qt.alpha(
                                                            Appearance.md3.outline_variant, 0.40)
            border.width: 1
            scale: rightNavMouse.pressed ? 0.94 : (rightNavMouse.containsMouse ? 1.08 : 1.0)

            Behavior on scale {
                SpringAnimation {
                    spring: 3.5
                    damping: 0.22
                    mass: 0.6
                    epsilon: 0.005
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.motion.fast
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                icon: "chevron_right"
                size: 26
                color: rightNavMouse.pressed ? Appearance.md3.on_primary : rightNavMouse.containsMouse
                                               ? Appearance.md3.primary : Appearance.md3.on_surface
            }

            MouseArea {
                id: rightNavMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wallpaperList.currentIndex === wallpaperList.count - 1)
                        wallpaperList.currentIndex = 0;
                    else
                        wallpaperList.incrementCurrentIndex();
                    wallpaperList.forceActiveFocus();
                }
            }
        }

        ListView {
            id: wallpaperList

            anchors.centerIn: parent
            width: parent.width
            // Altura aumentada para mostrar imágenes más altas y destacadas
            height: 360

            model: root.filtered
            orientation: ListView.Horizontal
            spacing: -70
            clip: false
            focus: true

            pixelAligned: true
            cacheBuffer: 1200
            snapMode: ListView.SnapToItem
            highlightMoveDuration: 220
            highlightFollowsCurrentItem: true

            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width / 2) - 280
            preferredHighlightEnd: (width / 2) + 280

            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1500
            maximumFlickVelocity: 2500

            onMovementEnded: {
                const targetIdx = indexAt(contentX + width / 2, height / 2);
                if (targetIdx >= 0 && targetIdx < count) {
                    currentIndex = targetIdx;
                }
                wallpaperList.forceActiveFocus();
            }

            header: Item {
                width: Math.max(0, wallpaperList.width / 2 - 280)
                height: 1
            }
            footer: Item {
                width: Math.max(0, wallpaperList.width / 2 - 280)
                height: 1
            }

            Keys.onUpPressed: searchField.forceActiveFocus()
            Keys.onTabPressed: searchField.forceActiveFocus()
            Keys.onBacktabPressed: searchField.forceActiveFocus()

            Keys.onLeftPressed: {
                currentIndex === 0 ? currentIndex = wallpaperList.count - 1 : decrementCurrentIndex();
            }
            Keys.onRightPressed: {
                currentIndex === wallpaperList.count - 1 ? currentIndex = 0 : incrementCurrentIndex();
            }
            Keys.onReturnPressed: root.applyCurrentWallpaper()

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
                    wallpaperList.forceActiveFocus();
                    if (wallpaperList.currentIndex === index) {
                        root.applyCurrentWallpaper();
                    } else {
                        wallpaperList.currentIndex = index;
                    }
                }
            }
        }

        // ── Píldoras de navegación y acciones adaptadas a Matugen y ratón ─────
        Row {
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 20
            }
            z: 10
            spacing: 8
            opacity: 0.95

            // Botón interactivo de navegación
            Rectangle {
                color: navPillMouse.containsMouse ? Appearance.md3.surface_container_high : Qt.alpha(
                                                        Appearance.md3.surface_container_low, 0.85)
                radius: 6
                implicitWidth: hint1.implicitWidth + 14
                implicitHeight: 26
                border.color: navPillMouse.containsMouse ? Appearance.md3.primary : Qt.alpha(
                                                               Appearance.md3.outline_variant, 0.35)
                border.width: 1

                StyledText {
                    id: hint1

                    anchors.centerIn: parent
                    text: root.label("wallpaper.hint_navigate", "← → Navegar")
                    font.pixelSize: 11
                    color: navPillMouse.containsMouse ? Appearance.md3.primary :
                                                        Appearance.md3.on_surface_variant
                }

                MouseArea {
                    id: navPillMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (wallpaperList.currentIndex === wallpaperList.count - 1)
                            wallpaperList.currentIndex = 0;
                        else
                            wallpaperList.incrementCurrentIndex();
                        wallpaperList.forceActiveFocus();
                    }
                }
            }

            // Botón interactivo de aplicar fondo seleccionado con ratón
            Rectangle {
                color: applyMouse.pressed ? Qt.darker(Appearance.md3.primary, 1.1) : applyMouse.containsMouse
                                            ? Appearance.md3.primary : Qt.alpha(
                                                  Appearance.md3.surface_container_low, 0.85)
                radius: 6
                implicitWidth: applyPillRow.implicitWidth + 16
                implicitHeight: 26
                border.color: applyMouse.containsMouse ? Appearance.md3.primary : Qt.alpha(
                                                             Appearance.md3.outline_variant, 0.35)
                border.width: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.motion.fast
                    }
                }

                Row {
                    id: applyPillRow

                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "check"
                        size: 13
                        color: applyMouse.containsMouse ? Appearance.md3.on_primary : Appearance.md3.primary
                    }

                    StyledText {
                        id: hint2

                        anchors.verticalCenter: parent.verticalCenter
                        text: root.label("wallpaper.hint_apply", "↵ Aplicar")
                        font.pixelSize: 11
                        font.weight: applyMouse.containsMouse ? Font.Bold : Font.Normal
                        color: applyMouse.containsMouse ? Appearance.md3.on_primary :
                                                          Appearance.md3.on_surface_variant
                    }
                }

                MouseArea {
                    id: applyMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        wallpaperList.forceActiveFocus();
                        root.applyCurrentWallpaper();
                    }
                }
            }

            // Píldora de contador
            Rectangle {
                color: Qt.alpha(Appearance.md3.surface_container_low, 0.85)
                radius: 6
                implicitWidth: countText.implicitWidth + 14
                implicitHeight: 26
                border.color: Qt.alpha(Appearance.md3.outline_variant, 0.35)
                border.width: 1

                StyledText {
                    id: countText

                    anchors.centerIn: parent
                    text: (wallpaperList.count > 0 ? wallpaperList.currentIndex + 1 : 0) + " / "
                          + wallpaperList.count
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Appearance.md3.primary
                }
            }
        }

        // Estado vacío
        EmptyState {
            anchors.centerIn: parent
            visible: root.filtered.length === 0
            icon: "image_not_supported"
            title: root.filtersActive ? root.label("wallpaper.no_match", "Ningún fondo coincide") : root.label(
                                            "wallpaper.no_results", "No se encontraron fondos")
            subtitle: root.filtersActive ? root.label("wallpaper.no_match_hint",
                                                      "Prueba a quitar algún filtro") : ""
            actionVisible: root.filtersActive
            actionText: root.label("wallpaper.filter.clear", "Limpiar")
            onActionClicked: root.clearFilters()
        }
    }
}
