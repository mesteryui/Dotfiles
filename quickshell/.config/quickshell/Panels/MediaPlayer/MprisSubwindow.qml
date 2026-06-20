// --- MediaPopup ---
// PopupWindow con controles MPRIS: arte de pista, título, artista,
// slider de progreso y botones prev/play/next.
// Consume MprisService — nunca accede al player directamente.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.Core.Services as Services
import qs.Core
import qs.Primitives

PopupWindow {
    id: root

    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: 300
    implicitHeight: content.implicitHeight

    // ── Focus grab ────────────────────────────────────────────
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible)
                Qt.callLater(() => root.visible = false)
        }
    }

    // ── Posición de reproducción ──────────────────────────────
    // Solo se mantiene aquí; la duración viene de MprisService.trackLength.
    // El guard !progressSlider.pressed evita que el timer pise el valor
    // mientras el usuario arrastra el slider.
    property real currentPosition: 0

    Timer {
        id: positionTimer
        interval: 250
        repeat: true
        running: root.visible && Services.MprisService.isPlaying
        onTriggered: {
            if (!progressSlider.pressed && Services.MprisService.currentMprisPlayer)
                root.currentPosition = Services.MprisService.currentMprisPlayer.position
        }
    }

    Timer {
        id: seekConfirmTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (Services.MprisService.currentMprisPlayer && !progressSlider.pressed)
                root.currentPosition = Services.MprisService.currentMprisPlayer.position
        }
    }

    // Actualiza posición desde el player (sin drag activo)
    Connections {
        target: Services.MprisService.currentMprisPlayer
        enabled: Services.MprisService.currentMprisPlayer !== null

        function onPositionChanged() {
            if (!progressSlider.pressed)
                root.currentPosition = Services.MprisService.currentMprisPlayer.position
        }

        function onPlaybackStateChanged() {
            // Qt.callLater: deja que el player actualice position antes de leerla
            Qt.callLater(() => {
                if (Services.MprisService.currentMprisPlayer && !progressSlider.pressed)
                    root.currentPosition = Services.MprisService.currentMprisPlayer.position
            })
        }
    }
    

    // Inicializa posición al abrir el popup
    onVisibleChanged: {
        if (visible)
            root.currentPosition = Services.MprisService.currentMprisPlayer?.position ?? 0
    }

    // Reinicia posición al cambiar de pista/player
    Connections {
        target: Services.MprisService
        function onCurrentMprisPlayerChanged() {
            root.currentPosition = Services.MprisService.currentMprisPlayer?.position ?? 0
        }
    }

    // ── Borde exterior (sobre el clip) ────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "transparent"
        border.color: Colors.md3.outline_variant
        border.width: 1
        z: 10
    }

    // ── Superficie principal ──────────────────────────────────
    Rectangle {
        id: content
        anchors.fill: parent
        radius: 20
        color: Colors.md3.surface
        clip: true
        implicitHeight: header.implicitHeight + controls.implicitHeight

        // ── Cabecera con arte ─────────────────────────────────
        Item {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            implicitHeight: 110

            // Fondo tonal
            Rectangle {
                anchors.fill: parent
                radius: content.radius
                color: Qt.alpha(Colors.md3.primary_container, 0.6)
            }

            // Arte de la pista (recortado al radio del panel)
            ClippingRectangle {
                color: "transparent"
                anchors.fill: parent
                radius: content.radius

                Image {
                    anchors.fill: parent
                    source: Services.MprisService.lastTrackArtUrl
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.3
                    z: 1

                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                }
            }

            // Degradado inferior para legibilidad del texto
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 60
                z: 2
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop {
                        position: 1.0
                        color: Qt.tint(Colors.md3.surface, Qt.alpha(Colors.md3.primary, 0.08))
                    }
                }
            }

            // Título y artista
            Column {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    margins: 16
                    bottomMargin: 10
                }
                spacing: 3
                z: 3

                Text {
                    width: parent.width
                    text: Services.MprisService.currentMprisPlayer?.trackTitle
                          ?? Services.I18nService.getTranslation("media.no_media")
                    font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Colors.md3.on_surface
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: Services.MprisService.currentMprisPlayer?.trackArtist
                          || Services.MprisService.currentMprisPlayer?.trackAlbumArtist
                          || ""
                    font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                    font.pixelSize: 12
                    color: Colors.md3.on_surface_variant
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }
        }

        // ── Controles ─────────────────────────────────────────
        Column {
            id: controls
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
            }
            topPadding: 12
            bottomPadding: 16
            leftPadding: 16
            rightPadding: 16
            spacing: 8

            // ── Tiempos ───────────────────────────────────────
            RowLayout {
                width: parent.width - parent.leftPadding - parent.rightPadding

                Text {
                    text: formatTime(root.currentPosition)
                    font.pixelSize: 11
                    font.family: Services.ConfigService.getConfig("fontMono") || "monospace"
                    color: Colors.md3.on_surface_variant
                }

                Item { Layout.fillWidth: true }

                Text {
                    // trackLength viene directo del servicio — sin property local
                    text: formatTime(Services.MprisService.trackLength)
                    font.pixelSize: 11
                    font.family: Services.ConfigService.getConfig("fontMono") || "monospace"
                    color: Colors.md3.on_surface_variant
                }
            }

            // ── Slider de progreso ────────────────────────────
            Slider {
                id: progressSlider
                width: parent.width - parent.leftPadding - parent.rightPadding
                from: 0.0
                to: 1.0

                value: Services.MprisService.trackLength > 0
                       ? Math.min(1.0, root.currentPosition / Services.MprisService.trackLength)
                       : 0.0

                onMoved: {
                    const newPos = value * Services.MprisService.trackLength
                    root.currentPosition = newPos
                    Services.MprisService.seekTo(newPos)
                }
            }

            // ── Botones prev / play / next ────────────────────
            RowLayout {
                width: parent.width - parent.leftPadding - parent.rightPadding
                spacing: 0
                implicitHeight: 44

                Item { Layout.fillWidth: true }

                ButtonIcon {
                    iconSize: 20
                    iconName: "skip_previous"
                    enabled: Services.MprisService.hasPlayer
                    onClicked: Services.MprisService.previousTrack()
                }

                // Botón play/pause con fondo circular
                Item {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8

                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: Colors.md3.primary_container
                    }

                    ButtonIcon {
                        anchors.centerIn: parent
                        iconSize: 22
                        iconName: Services.MprisService.isPlaying ? "pause" : "play_arrow"
                        enabled: Services.MprisService.hasPlayer
                        onClicked: Services.MprisService.togglePlaying()
                        iconColor: Colors.md3.on_primary_container
                    }
                }

                ButtonIcon {
                    iconSize: 20
                    iconName: "skip_next"
                    enabled: Services.MprisService.hasPlayer
                    onClicked: Services.MprisService.nextTrack()
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // ── Utilidades ────────────────────────────────────────────
    function formatTime(seconds: real): string {
        const totalSec = Math.floor(seconds)
        const h = Math.floor(totalSec / 3600)
        const m = Math.floor((totalSec % 3600) / 60)
        const s = totalSec % 60

        if (h > 0) {
            return String(h).padStart(2, "0") + ":"
                 + String(m).padStart(2, "0") + ":"
                 + String(s).padStart(2, "0")
        }
        return m + ":" + String(s).padStart(2, "0")
    }
}