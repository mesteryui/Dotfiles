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

    // El modelo es el FolderListModel del servicio: sin capa intermedia.
    // (Antes había un array filtrado por búsqueda, pero la barra de
    // búsqueda no existe: código muerto eliminado.)

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // ── Cabecera ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: Appearance.spacing.m

            StyledText {
                text: Services.I18nService?.getTranslation("wallpaper.title", "Fondos de Pantalla") ?? "Fondos de Pantalla"
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Bold
                font.family: Appearance.font.sans
                color: Appearance.md3.on_surface
                verticalAlignment: Text.AlignVCenter
            }

            // Contador de elementos
            Rectangle {
                color: Appearance.md3.surface_container_high
                radius: Appearance.shape.small
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
                    radius: Appearance.shape.unsharpenmore
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
                    radius: Appearance.shape.unsharpenmore
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

        // ── Carrusel / Coverflow ListView ────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: wallpaperList

                anchors.fill: parent
                model: Services.WallpaperService.wallpaperList
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

                delegate: WallpaperItem {
                    onClicked: {
                        wallpaperList.currentIndex = index;
                        root.applyCurrentWallpaper();
                    }
                }
            }

            // Estado vacío cuando la carpeta no tiene fondos
            StyledText {
                anchors.centerIn: parent
                visible: wallpaperList.count === 0
                text: Services.I18nService?.getTranslation("wallpaper.no_results", "No se encontraron fondos") ?? "No se encontraron fondos"
                font.pixelSize: Appearance.typeScale.bodyLarge
                color: Appearance.md3.on_surface_variant
            }
        }
    }

    function applyCurrentWallpaper() {
        if (!wallpaperList.currentItem)
            return;
        const fileName = Services.WallpaperService.wallpaperList.get(wallpaperList.currentIndex, "fileName") ?? "";
        if (fileName !== "") {
            Services.WallpaperService.apply(fileName);
            root.hideRequested();
        }
    }
}
