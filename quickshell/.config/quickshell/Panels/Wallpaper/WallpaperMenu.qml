import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick.Controls
import qs.Core
import qs.Core.Services as Services
import qs.Panels.Wallpaper
import QtQuick.Layouts

PanelWindow {
    id: wallpaperMenu
    implicitWidth: 800
    implicitHeight: 280
    visible: content.opacity > 0           // ✅ siempre visible — la animación va en el contenido
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore
    WlrLayershell.namespace: "wallpaper-menu"

    Region { id: emptyRegion }
    Region { id: activeRegion; item: content }

    mask: showing ? activeRegion : emptyRegion
    
    property bool showing: false

    function show() { showing = true }
    function hide() { showing = false }

    HyprlandFocusGrab {
        windows: [wallpaperMenu]
        active: wallpaperMenu.showing
        onCleared: {
            if (wallpaperMenu.showing)
                Qt.callLater(() => wallpaperMenu.showing = false)
        }
    }

    onShowingChanged: {
        if (showing) wallpaperList.forceActiveFocus()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: wallpaperMenu.showing = false
    }

    IpcHandler {
        target: "ui.wallpaperMenu"
        function toggleWallpaperMenu(): void {
            wallpaperMenu.showing = !wallpaperMenu.showing
        }
    }

    // ── Contenido animado — la ventana no se toca ─────────────
    Item {
        id: content
        anchors.fill: parent

        // ✅ la animación va aquí, no en la PanelWindow
        opacity: wallpaperMenu.showing ? 1.0 : 0.0
        scale: wallpaperMenu.showing ? 1.0 : 0.95
        transformOrigin: Item.Bottom  // crece desde abajo si la barra está arriba

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        // ── Borde exterior ────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: "transparent"
            border.color: Colors.md3.outline_variant  // ✅ era outline
            border.width: 1
            z: 10
        }

        // ── Contenedor principal ──────────────────────────────
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Colors.md3.surface
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // ── Cabecera ──────────────────────────────────
                RowLayout {
                    width: parent.width
                    height: 20

                    Label {
                        text: Services.I18nService?.getTranslation("wallpaper.title","Wallpapers")
                        font.family: Services.ConfigService.configs.appearence.fontSans
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        color: Colors.md3.on_surface
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // ── Lista de wallpapers ───────────────────────
                ListView {
                    id: wallpaperList
                    width: parent.width
                    height: 210
                    model: Services.WallpaperService.wallpaperList
                    orientation: ListView.Horizontal
                    spacing: 12          // ✅ 16 → 12, más compacto y MD3
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
                            wallpaperMenu.showing = false
                        }
                    }

                    delegate: WallpaperItem {}
                }
            }
        }
    }
}