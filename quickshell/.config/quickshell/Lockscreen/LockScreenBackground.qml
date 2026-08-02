import QtQuick
import QtQuick.Effects
import qs.Core
import qs.Core.Modules
Item {
    id: root
    anchors.fill: parent

    // ── Contexto & Apariencia ─────────────────────────────────────────
    property string wallpaperPath: "file://" + Persistent.persistence.currentWallpaper
    property real scrimAlpha: 0.30
    property real blurAmount: 1.0

    // ── Helper de color ───────────────────────────────────────────────
    function withAlpha(hexColor, alphaValue) {
        var c = Qt.color(hexColor);
        return Qt.rgba(c.r, c.g, c.b, alphaValue);
    }

    // ── Fondo de Wallpaper ────────────────────────────────────────────
    Image {
        id: wallpaperBg
        anchors.fill: parent
        source: root.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    // ── Efecto de Desenfoque ──────────────────────────────────────────
    MultiEffect {
        anchors.fill: wallpaperBg
        source: wallpaperBg
        blurEnabled: true
        blur: root.blurAmount
        blurMax: 48
        blurMultiplier: 1.0
        autoPaddingEnabled: false
    }

    // ── Capa de Tinte (Scrim) ──────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.withAlpha(Appearance.md3.scrim, root.scrimAlpha)
    }
}
