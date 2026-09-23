// --- WallhavenWindowContent: buscar y descargar fondos de wallhaven.cc ---
// Filtros como la web + descarga a la carpeta local (WallpaperService) con
// opción de aplicar al instante.
pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    function tr(key, fallback) {
        return Services.I18nService.getTranslation(key || "", fallback || "");
    }

    function errorText() {
        const code = Services.WallhavenService.errorCode;
        if (code === "")
            return "";
        if (code === "http")
            return tr("wallhaven.error_http", "Error HTTP %1").arg(Services.WallhavenService.errorDetail);
        if (code === "invalid")
            return tr("wallhaven.error_invalid", "Respuesta inválida");
        if (code === "offline")
            return tr("wallhaven.error_offline", "Sin conexión");
        return tr("wallhaven.error_download", "Descarga fallida");
    }

    function surprise() {
        const prev = Services.WallhavenService.sorting;
        Services.WallhavenService.sorting = "random";
        Services.WallhavenService.search(true);
        Services.WallhavenService.sorting = prev;
    }

    // Búsquedas con debounce: filtros y texto solo reprograman (una sola
    // petición al ajustar varios seguidos); botón/Enter/reintentar son
    // inmediatos.
    Timer {
        id: filterDebounce

        interval: 600
        onTriggered: Services.WallhavenService.search(true)
    }
    function queueSearch() {
        filterDebounce.restart();
    }

    Timer {
        id: textDebounce

        interval: 700
        onTriggered: {
            Services.WallhavenService.query = searchField.text;
            Services.WallhavenService.search(true);
        }
    }

    component FilterChip: Rectangle {
        id: chip

        required property string label
        required property bool active
        property bool locked: false
        signal toggled

        implicitWidth: chipLabel.implicitWidth + 24
        implicitHeight: 30
        radius: 15
        color: chip.active ? Appearance.md3.secondary_container : "transparent"
        border.width: chip.active ? 0 : 1
        border.color: Appearance.md3.outline_variant
        opacity: chip.locked ? 0.45 : 1.0

        StyledText {
            id: chipLabel

            anchors.centerIn: parent
            text: chip.label
            font.pixelSize: 12
            color: chip.active ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: chip.locked ? Qt.ForbiddenCursor : Qt.PointingHandCursor
            onClicked: {
                if (!chip.locked)
                    chip.toggled();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // ── Título + estado ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            StyledText {
                text: root.tr("wallhaven.title", "Wallhaven")
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.Bold
                font.family: Appearance.font.sans
                color: Appearance.md3.on_surface
            }

            StyledText {
                text: Services.WallhavenService.loading ? root.tr("wallhaven.loading", "Cargando…") : root.errorText() !== "" ? root.errorText() : root.tr("wallhaven.results", "%1 resultados").arg(Services.WallhavenService.total)
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.errorText() !== "" ? Appearance.md3.error : Appearance.md3.on_surface_variant
            }

            Item {
                Layout.fillWidth: true
            }

            // Paginación
            AnimatedTextButton {
                text: "‹"
                fontSize: 16
                paddingHorizontal: 16
                onClicked: Services.WallhavenService.prevPage()
            }

            StyledText {
                text: root.tr("wallhaven.page", "Página %1 de %2").arg(Services.WallhavenService.page).arg(Math.max(1, Services.WallhavenService.lastPage))
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.md3.on_surface_variant
            }

            AnimatedTextButton {
                text: "›"
                fontSize: 16
                paddingHorizontal: 16
                onClicked: Services.WallhavenService.nextPage()
            }
        }

        // ── Búsqueda ─────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialTextField {
                id: searchField

                Layout.fillWidth: true
                placeholderText: root.tr("wallhaven.search_placeholder", "Buscar fondos…")
                text: Services.WallhavenService.query
                onTextChanged: textDebounce.restart()
                onAccepted: {
                    textDebounce.stop();
                    Services.WallhavenService.query = text;
                    Services.WallhavenService.search(true);
                }
            }

            AnimatedTextButton {
                text: "⌕"
                fontSize: 16
                isFilled: true
                paddingHorizontal: 20
                onClicked: {
                    Services.WallhavenService.query = searchField.text;
                    Services.WallhavenService.search(true);
                }
            }

            AnimatedTextButton {
                text: root.tr("wallhaven.random", "Aleatorio")
                onClicked: root.surprise()
            }
        }

        // ── Filtros: categorías + pureza ─────────────────────────────
        Flow {
            Layout.fillWidth: true
            spacing: 6

            FilterChip {
                label: root.tr("wallhaven.cat_general", "General")
                active: Services.WallhavenService.catGeneral
                onToggled: {
                    Services.WallhavenService.catGeneral = !Services.WallhavenService.catGeneral;
                    root.queueSearch();
                }
            }

            FilterChip {
                label: root.tr("wallhaven.cat_anime", "Anime")
                active: Services.WallhavenService.catAnime
                onToggled: {
                    Services.WallhavenService.catAnime = !Services.WallhavenService.catAnime;
                    root.queueSearch();
                }
            }

            FilterChip {
                label: root.tr("wallhaven.cat_people", "Gente")
                active: Services.WallhavenService.catPeople
                onToggled: {
                    Services.WallhavenService.catPeople = !Services.WallhavenService.catPeople;
                    root.queueSearch();
                }
            }

            FilterChip {
                label: root.tr("wallhaven.purity_sfw", "SFW")
                active: Services.WallhavenService.puritySfw
                onToggled: {
                    Services.WallhavenService.puritySfw = !Services.WallhavenService.puritySfw;
                    root.queueSearch();
                }
            }

            FilterChip {
                label: root.tr("wallhaven.purity_sketchy", "Sketchy")
                active: Services.WallhavenService.puritySketchy
                onToggled: {
                    Services.WallhavenService.puritySketchy = !Services.WallhavenService.puritySketchy;
                    root.queueSearch();
                }
            }

            FilterChip {
                label: root.tr("wallhaven.purity_nsfw", "NSFW")
                active: Services.WallhavenService.purityNsfw && Services.WallhavenService.apiKey !== ""
                locked: Services.WallhavenService.apiKey === ""
                onToggled: {
                    Services.WallhavenService.purityNsfw = !Services.WallhavenService.purityNsfw;
                    root.queueSearch();
                }
            }
        }

        // ── Filtros: orden + resolución mínima ───────────────────────
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    {
                        id: "relevance",
                        label: root.tr("wallhaven.sort_relevance", "Relevancia")
                    },
                    {
                        id: "date_added",
                        label: root.tr("wallhaven.sort_date_added", "Recientes")
                    },
                    {
                        id: "views",
                        label: root.tr("wallhaven.sort_views", "Visitas")
                    },
                    {
                        id: "favorites",
                        label: root.tr("wallhaven.sort_favorites", "Favoritos")
                    },
                    {
                        id: "toplist",
                        label: root.tr("wallhaven.sort_toplist", "Top")
                    }
                ]

                FilterChip {
                    required property var modelData

                    label: modelData.label
                    active: Services.WallhavenService.sorting === modelData.id
                    onToggled: {
                        Services.WallhavenService.sorting = modelData.id;
                        root.queueSearch();
                    }
                }
            }

            FilterChip {
                label: Services.WallhavenService.order === "desc" ? "↓" : "↑"
                active: true
                onToggled: {
                    Services.WallhavenService.order = Services.WallhavenService.order === "desc" ? "asc" : "desc";
                    root.queueSearch();
                }
            }

            FilterChip {
                label: root.tr("wallhaven.atleast_any", "Todas")
                active: Services.WallhavenService.atleast === ""
                onToggled: {
                    Services.WallhavenService.atleast = "";
                    root.queueSearch();
                }
            }

            Repeater {
                model: ["1920x1080", "2560x1440", "3440x1440", "3840x2160"]

                FilterChip {
                    required property var modelData

                    label: modelData
                    active: Services.WallhavenService.atleast === modelData
                    onToggled: {
                        Services.WallhavenService.atleast = Services.WallhavenService.atleast === modelData ? "" : modelData;
                        root.queueSearch();
                    }
                }
            }
        }

        // ── Rango del toplist ────────────────────────────────────────
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: Services.WallhavenService.sorting === "toplist"

            Repeater {
                model: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]

                FilterChip {
                    required property var modelData

                    label: modelData
                    active: Services.WallhavenService.topRange === modelData
                    onToggled: {
                        Services.WallhavenService.topRange = modelData;
                        root.queueSearch();
                    }
                }
            }
        }

        // ── Resultados ─────────────────────────────────────────────
        GridView {
            id: resultGrid

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: 228
            cellHeight: 210
            model: Services.WallhavenService.results
            // Se atenúa mientras carga para que el estado sea evidente.
            opacity: Services.WallhavenService.loading ? 0.4 : 1
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: 216
                height: 198
                radius: 14
                color: Appearance.md3.surface_container_low
                border.width: 1
                border.color: Appearance.md3.outline_variant

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Image {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 110
                        source: modelData.thumb
                        asynchronous: true
                        cache: true
                        // Miniatura ~200px: acota el decode al 2x visible.
                        sourceSize.width: 400
                        sourceSize.height: 220
                        fillMode: Image.PreserveAspectCrop
                        smooth: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.lightboxItem = modelData
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.resolution + " · " + modelData.sizeLabel + " · ♥" + modelData.favorites
                        font.pixelSize: 11
                        color: Appearance.md3.on_surface_variant
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        AnimatedTextButton {
                            Layout.fillWidth: true
                            text: Services.WallhavenService.busyId === modelData.id ? root.tr("wallhaven.downloading", "Bajando…") : (Services.WallhavenService.isDownloaded(modelData.id) ? root.tr("wallhaven.downloaded", "Bajado") : root.tr("wallhaven.download", "Descargar"))
                            fontSize: 12
                            paddingHorizontal: 8
                            onClicked: Services.WallhavenService.download(modelData, false)
                        }

                        AnimatedTextButton {
                            Layout.fillWidth: true
                            text: root.tr("wallhaven.apply", "Aplicar")
                            fontSize: 12
                            isFilled: true
                            paddingHorizontal: 8
                            onClicked: Services.WallhavenService.applyNow(modelData)
                        }
                    }
                }
            }
        }

        // ── Vacío / error ────────────────────────────────────────
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: !Services.WallhavenService.loading && Services.WallhavenService.results.length === 0 && Services.WallhavenService.errorCode === ""
            text: root.tr("wallhaven.empty", "Busca algo o pulsa Aleatorio")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.md3.on_surface_variant
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: !Services.WallhavenService.loading && Services.WallhavenService.errorCode !== ""
            spacing: 10

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "cloud_off"
                size: 52
                color: Appearance.md3.error
                opacity: 0.8
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.errorText()
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.md3.error
                horizontalAlignment: Text.AlignHCenter
            }

            AnimatedTextButton {
                Layout.alignment: Qt.AlignHCenter
                text: root.tr("wallhaven.retry", "Reintentar")
                isFilled: true
                onClicked: Services.WallhavenService.search(false)
            }
        }
    }

    // ── Lightbox: vista grande + acciones ──────────────────────────
    // Clic en una miniatura → imagen a tamaño completo sin salir.
    property var lightboxItem: null

    Item {
        anchors.fill: parent
        visible: root.lightboxItem !== null

        Rectangle {
            anchors.fill: parent
            color: Appearance.md3.scrim
            opacity: 0.8
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.lightboxItem = null
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Image {
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: root.lightboxItem ? root.lightboxItem.imageUrl : ""
                asynchronous: true
                cache: false
                // Vista a pantalla: acota el decode para no masticar
                // wallpapers 4K+ a resolución completa.
                sourceSize.width: 1920
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.lightboxItem ? (root.lightboxItem.resolution + " · " + root.lightboxItem.sizeLabel + " · ♥" + root.lightboxItem.favorites) : ""
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.md3.on_surface
                    elide: Text.ElideRight
                }
                AnimatedTextButton {
                    text: root.lightboxItem && Services.WallhavenService.busyId === root.lightboxItem.id ? root.tr("wallhaven.downloading", "Bajando…") : (root.lightboxItem && Services.WallhavenService.isDownloaded(root.lightboxItem.id) ? root.tr("wallhaven.downloaded", "Bajado") : root.tr("wallhaven.download", "Descargar"))
                    fontSize: 13
                    onClicked: Services.WallhavenService.download(root.lightboxItem, false)
                }
                AnimatedTextButton {
                    text: root.tr("wallhaven.apply", "Aplicar")
                    fontSize: 13
                    isFilled: true
                    onClicked: {
                        Services.WallhavenService.applyNow(root.lightboxItem);
                        root.lightboxItem = null;
                    }
                }
                AnimatedTextButton {
                    text: root.tr("wallhaven.close", "Cerrar")
                    fontSize: 13
                    onClicked: root.lightboxItem = null
                }
            }
        }
    }

    Component.onCompleted: {
        if (Services.WallhavenService.results.length === 0 && !Services.WallhavenService.loading)
            Services.WallhavenService.search(true);
    }
}
