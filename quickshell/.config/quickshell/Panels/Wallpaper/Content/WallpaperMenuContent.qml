// --- WallpaperMenuContent (Content) ---
// Responsabilidades: layout visual del picker de wallpapers.
// NO referencia al Wrapper (wallpaperMenu) ni al Background.
// Comunica hacia afuera exclusivamente mediante señales.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Core
import qs.Core.Services as Services
import qs.Panels.Wallpaper
import qs.Primitives

Item {
    id: root

    // ── API pública ───────────────────────────────────────────────────────────
    // El Wrapper llama a requestFocus() al mostrar el panel.
    function requestFocus() {
        wallpaperList.forceActiveFocus()
    }

    // El Wrapper escucha esta señal para cerrar el popup.
    signal hideRequested()

    // ── Layout ────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 12

        // ── Cabecera ──────────────────────────────────────────────────────────
        RowLayout {
            width: parent.width
            height: 20


            StyledText {
                text: Services.I18nService?.getTranslation("wallpaper.title", "Wallpapers") ?? "Wallpapers"
                font.pixelSize: Appearance.font.pixelSize.title
                font.variableAxes: Appearance.font.variableAxes.title
                font.family: Appearance.font.sans
                color: Appearance.md3.on_surface
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
            }
        }


        // ── Lista de wallpapers ───────────────────────────────────────────────
        ListView {
            id: wallpaperList
            width: parent.width
            height: 210
            model: Services.WallpaperService.wallpaperList
            orientation: ListView.Horizontal
            spacing: 12
            clip: false
            focus: true

            pixelAligned: true
            cacheBuffer: 1200
            snapMode: ListView.SnapToItem
            highlightMoveDuration: 250
            highlightFollowsCurrentItem: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1500
            maximumFlickVelocity: 2500
            
            // ── Navegación por teclado ────────────────────────────────────────
            Keys.onLeftPressed: {
                currentIndex === 0
                    ? currentIndex = model.count - 1
                    : decrementCurrentIndex()
            }
            

            Keys.onRightPressed: {
                currentIndex === model.count - 1
                    ? currentIndex = 0
                    : incrementCurrentIndex()
            }
            Keys.onReturnPressed: {
                if (!currentItem) return
                const fileName = model.get(currentIndex, "fileName")
                if (fileName) {
                    Services.WallpaperService.apply(fileName)
                    root.hideRequested()      // ← señal, no referencia directa
                }
            }

            delegate: WallpaperItem {}
        }
    }
}
