pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Modules
import qs.Core.Services
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Item {
    id: root

    anchors.fill: parent

    required property ShellScreen targetScreen

    readonly property bool isDark: ConfigService.configs.appearence.darkMode
    property real scrimAlpha: isDark ? 0.32 : 0.22

    function withAlpha(hexColor, alphaValue) {
        var c = Qt.color(hexColor);
        return Qt.rgba(c.r, c.g, c.b, alphaValue);
    }

    Item {
        id: background

        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: ConfigService.configs.lockscreen.blurLevel
            blurMax: 64
            blurMultiplier: 1
        }

        Loader {
            anchors.fill: parent
            sourceComponent: ConfigService.configs.lockscreen.useWallpaper ? wallpaperBackground : screenCopyBackground
        }
    }

    // ── Scrim para legibilidad ──────────────────────────────────────
    // Capa oscura en tema oscuro / clara en tema claro, para asegurar
    // que el texto (on_surface, etc.) se lea bien sobre cualquier fondo.
    Rectangle {
        anchors.fill: parent
        color: root.isDark ? Qt.rgba(0, 0, 0, root.scrimAlpha) : Qt.rgba(1, 1, 1, root.scrimAlpha)
    }

    // ── Fondo de Wallpaper ────────────────────────────────────────────
    Component {
        id: wallpaperBackground

        Image {
            source: Qt.resolvedUrl(Persistent.persistence.currentWallpaper)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    Component {
        id: screenCopyBackground

        ScreencopyView {
            captureSource: root.targetScreen
        }
    }
}
