pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Panels.Wallpaper
import qs.Primitives
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    function requestFocus() {
        wallpaperList.forceActiveFocus();
    }

    signal hideRequested

    // ── Búsqueda ──────────────────────────────────────────────────────────
    // FolderListModel no expone filtrado nativo, así que reconstruimos un
    // array plano (filePath/fileName) cada vez que cambia el texto. Los
    // nombres de rol usados aquí (fileName, filePath) son los mismos que
    // ya usaba applyCurrentWallpaper() y WallpaperItem.modelData.filePath.
    property string searchQuery: ""

    property var filteredWallpapers: []

    function rebuildFilteredList() {
        const source = Services.WallpaperService.wallpaperList;
        const query = root.searchQuery.trim().toLowerCase();
        const result = [];
        for (let i = 0; i < source.count; i++) {
            const fileName = source.get(i, "fileName") ?? "";
            if (query.length === 0 || fileName.toLowerCase().includes(query)) {
                result.push({
                    filePath: source.get(i, "filePath") ?? "",
                    fileName: fileName
                });
            }
        }
        root.filteredWallpapers = result;
        if (wallpaperList.currentIndex >= result.length)
            wallpaperList.currentIndex = Math.max(0, result.length - 1);
    }

    onSearchQueryChanged: rebuildFilteredList()
    Component.onCompleted: rebuildFilteredList()

    // Si el contenido de la carpeta cambia (fondo agregado/borrado), re-filtrar
    Connections {
        target: Services.WallpaperService.wallpaperList

        function onCountChanged() {
            root.rebuildFilteredList();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── Cabecera ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 12

            StyledText {
                text: Services.I18nService?.getTranslation("wallpaper.title", "Wallpapers") ?? "Wallpapers"
                font.pixelSize: Appearance.font.pixelSize.title
                font.weight: Font.Bold
                font.family: Appearance.font.sans
                color: Appearance.md3.on_surface
                verticalAlignment: Text.AlignVCenter
            }

            // Contador de elementos, ya refleja el resultado filtrado
            Rectangle {
                color: Appearance.md3.surface_container_high
                radius: 12
                implicitWidth: countText.implicitWidth + 16
                implicitHeight: 24

                StyledText {
                    id: countText

                    anchors.centerIn: parent
                    text: (wallpaperList.count > 0 ? wallpaperList.currentIndex + 1 : 0) + " / " + wallpaperList.count
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Appearance.md3.primary
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Píldoras de ayuda rápida de teclado
            Row {
                spacing: 6

                Rectangle {
                    color: Qt.rgba(1, 1, 1, 0.06)
                    radius: 6
                    implicitWidth: hint1.implicitWidth + 12
                    implicitHeight: 22
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    StyledText {
                        id: hint1

                        anchors.centerIn: parent
                        text: "← → Navegar"
                        font.pixelSize: 10
                        color: Appearance.md3.on_surface_variant
                    }
                }

                Rectangle {
                    color: Qt.rgba(1, 1, 1, 0.06)
                    radius: 6
                    implicitWidth: hint2.implicitWidth + 12
                    implicitHeight: 22
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    StyledText {
                        id: hint2

                        anchors.centerIn: parent
                        text: "↵ Aplicar"
                        font.pixelSize: 10
                        color: Appearance.md3.on_surface_variant
                    }
                }
            }
        }

        // ── Barra de búsqueda ────────────────────────────────────────────


        // ── Carrusel / Coverflow ListView ────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: wallpaperList

                anchors.fill: parent
                model: root.filteredWallpapers
                orientation: ListView.Horizontal
                spacing: 20 // positivo: evita que las tarjetas se pisen entre sí
                clip: false
                focus: true

                pixelAligned: true
                cacheBuffer: 1200
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

                // Navegación por teclado (usa wallpaperList.count, no
                // model.count: el modelo ahora es un array filtrado plano)
                Keys.onLeftPressed: {
                    currentIndex === 0 ? currentIndex = wallpaperList.count - 1 : decrementCurrentIndex();
                }

                Keys.onRightPressed: {
                    currentIndex === wallpaperList.count - 1 ? currentIndex = 0 : incrementCurrentIndex();
                }

                Keys.onReturnPressed: root.applyCurrentWallpaper()

                delegate: WallpaperItem {
                    onClicked: {
                        wallpaperList.currentIndex = index;
                        root.applyCurrentWallpaper();
                    }
                }
            }

            // Estado vacío cuando la búsqueda no encuentra nada
            StyledText {
                anchors.centerIn: parent
                visible: root.filteredWallpapers.length === 0
                text: Services.I18nService?.getTranslation("wallpaper.no_results", "No se encontraron fondos") ?? "No se encontraron fondos"
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.md3.on_surface_variant
            }
        }
    }

    function applyCurrentWallpaper() {
        if (!wallpaperList.currentItem)
            return;
        const entry = root.filteredWallpapers[wallpaperList.currentIndex];
        if (entry?.fileName) {
            Services.WallpaperService.apply(entry.fileName);
            root.hideRequested();
        }
    }
}
