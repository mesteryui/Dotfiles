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

    readonly property bool isDark: ConfigService.configs.appearance.darkMode
    readonly property bool useWallpaper: ConfigService.configs.lockscreen.useWallpaper
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
            // MultiEffect.blur trabaja en 0..1: se clamp el valor de
            // config (por defecto 1.3) para no romper la capa.
            blur: Math.min(1, Math.max(0, ConfigService.configs.lockscreen.blurLevel))
            blurMax: 64
            blurMultiplier: 1
        }

        // ── Base opaca: nunca negro ───────────────────────────────
        // Primer frame garantizado mientras el resto carga.
        Rectangle {
            anchors.fill: parent
            color: Appearance.md3.surface_dim
        }

        // ── Screencopy ────────────────────────────────────────────
        // Solo cuando useWallpaper es false. Con wallpaper activado no
        // se muestra nunca: durante su carga se ve la base opaca.
        ScreencopyView {
            id: screenCopy

            anchors.fill: parent
            captureSource: root.targetScreen
            visible: !root.useWallpaper
        }

        // ── Wallpaper, directo ────────────────────────────────────
        // Sin Loader ni fundidos: la imagen aparece tal cual en cuanto
        // está lista. Mientras carga se ve la base opaca (nunca negro,
        // nunca screencopy). Siempre el estático persistido.
        Image {
            id: wallpaper

            anchors.fill: parent
            // Sin fondo elegido (instalación fresca) no se resuelve nada:
            // Qt.resolvedUrl("") apuntaría al propio directorio QML.
            source: {
                const persisted = Persistent.persistence.currentWallpaper || "";
                const chosen = root.useWallpaper ? persisted : "";
                return chosen !== "" ? Qt.resolvedUrl(chosen) : "";
            }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            // Decodificar a la pantalla (no a 1920 fijo): en 1080p ahorra
            // ~3x memoria de textura y en 4K no pierde nitidez. Con guarda
            // nula: targetScreen se inyecta tras crear el item.
            sourceSize.width: root.targetScreen ? root.targetScreen.width : 1920
            sourceSize.height: root.targetScreen ? root.targetScreen.height : 1080
        }
    }

    // ── Scrim para legibilidad ──────────────────────────────────────
    // Capa oscura en tema oscuro / clara en tema claro, para asegurar
    // que el texto (on_surface, etc.) se lea bien sobre cualquier fondo.
    Rectangle {
        anchors.fill: parent
        color: root.isDark ? Qt.rgba(0, 0, 0, root.scrimAlpha) : Qt.rgba(1, 1, 1, root.scrimAlpha)
    }
}
