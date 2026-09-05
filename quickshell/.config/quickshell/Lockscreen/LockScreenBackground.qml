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

    property real scrimAlpha: 0.30

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
