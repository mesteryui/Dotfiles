// MprisContent — Content
// Toda la UI del popup de media. Sin fondos ni sombras.
// Expone sliderDragging para que el Wrapper gestione los timers.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import Quickshell.Widgets
import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import Quickshell.Services.Mpris

Item {
    id: root

    // ── API con el Wrapper ────────────────────────────────────
    required property real currentPosition
    signal seekRequested(real newPosition)

    // El Wrapper lo consulta en sus Timers y Connections
    readonly property bool sliderDragging: progressSlider.pressed

    readonly property bool multiPlayer: Services.MprisService.players.length > 1

    implicitHeight: header.implicitHeight
                  + controls.implicitHeight
                  + (multiPlayer ? playerSelector.implicitHeight : 0)

    // ── Cabecera: arte, título, artista ───────────────────────
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
            radius: 20
            color: Qt.alpha(Colors.md3.primary_container, 0.6)
        }

        // Arte de la pista recortado al radio del panel
        ClippingRectangle {
            anchors.fill: parent
            radius: 20
            color: "transparent"

            Image {
                anchors.fill: parent
                source: Services.MprisService.lastTrackArtUrl
                fillMode: Image.PreserveAspectCrop
                opacity: 0.3
                z: 1
                Behavior on opacity { NumberAnimation { duration: 300 } }
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

            StyledText {
                width: parent.width
                text: Services.MprisService.currentMprisPlayer?.trackTitle
                      ?? Services.I18nService.getTranslation("media.no_media")
                font.family: Services.ConfigService.configs.appearence.fontSans
                font.pixelSize: 15
                font.weight: Font.Bold
                color: Colors.md3.on_surface
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: Services.MprisService.currentMprisPlayer?.trackArtist
                      || Services.MprisService.currentMprisPlayer?.trackAlbumArtist
                      || ""
                font.family: Services.ConfigService.configs.appearence.fontSans
                font.pixelSize: 12
                color: Colors.md3.on_surface_variant
                elide: Text.ElideRight
                visible: text !== ""
            }
        }
    }

    // ── Controles: slider y botones ───────────────────────────
    Column {
        id: controls
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
        }
        topPadding: 12
        bottomPadding: root.multiPlayer ? 8 : 16
        leftPadding: 16
        rightPadding: 16
        spacing: 8

        // Tiempos
        RowLayout {
            width: parent.width - parent.leftPadding - parent.rightPadding

            Text {
                text: root.formatTime(root.currentPosition)
                font.pixelSize: 11
                font.family: Services.ConfigService.configs.appearence.monospace
                color: Colors.md3.on_surface_variant
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.formatTime(Services.MprisService.trackLength)
                font.pixelSize: 11
                font.family: Services.ConfigService.configs.appearence.monospace
                color: Colors.md3.on_surface_variant
            }
        }

        // Slider de progreso
        Slider {
            id: progressSlider
            Material.accent: Colors.md3.primary
            Material.background: Colors.md3.background
            Material.foreground: Colors.md3.on_background
    
            width: parent.width - parent.leftPadding - parent.rightPadding
            from: 0.0
            to: 1.0

            value: Services.MprisService.trackLength > 0
                   ? Math.min(1.0, root.currentPosition / Services.MprisService.trackLength)
                   : 0.0

            onMoved: root.seekRequested(value * Services.MprisService.trackLength)
        }

        // Botones prev / play / next
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

            // Botón play/pause — Wrapper + Background + Content inline
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
                    iconColor: Colors.md3.on_primary_container
                    onClicked: Services.MprisService.togglePlaying()
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

    // ── Selector de reproductor ───────────────────────────────
    // Solo visible cuando hay más de un player activo.
    // Chips de selección: activo → primary_container, resto → outline_variant border.
    Item {
        id: playerSelector
        anchors {
            top: controls.bottom
            left: parent.left
            right: parent.right
            leftMargin: 16
            rightMargin: 16
            bottomMargin: 12
        }
        implicitHeight: visible ? chipsRow.implicitHeight + 12 : 0
        visible: root.multiPlayer

        // Chips en fila; si hay muchos players se desbordan con scroll horizontal.
        Row {
            id: chipsRow
            anchors {
                top: parent.top
                topMargin: 0
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 6

            Repeater {
                model: Services.MprisService.players

                delegate: Item {
                    id: chipWrapper

                    // Captura la referencia antes del delegate para evitar
                    // el bug de `root` undefined dentro del Repeater.
                    required property var modelData
                    property MprisPlayer player: modelData

                    readonly property bool isActive:
                        Services.MprisService.currentMprisPlayer === player

                    implicitWidth: chipLabel.implicitWidth + 24
                    implicitHeight: 28

                    // Fondo del chip
                    Rectangle {
                        id: chipBg
                        anchors.fill: parent
                        radius: 9999
                        color: chipWrapper.isActive
                               ? Colors.md3.primary_container
                               : "transparent"
                        border.width: chipWrapper.isActive ? 0 : 1
                        border.color: Colors.md3.outline_variant

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    // State layer hover/press
                    Rectangle {
                        id: stateLayer
                        anchors.fill: parent
                        radius: 9999
                        color: chipWrapper.isActive
                               ? Colors.md3.on_primary_container
                               : Colors.md3.on_surface
                        opacity: 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    // Nombre del reproductor
                    StyledText {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chipWrapper.player.identity ?? chipWrapper.player.dbusName
                        font.family: Services.ConfigService.configs.appearence.fontSans
                        font.pixelSize: 11
                        color: chipWrapper.isActive
                               ? Colors.md3.on_primary_container
                               : Colors.md3.on_surface_variant
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    // Interacción
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: stateLayer.opacity = 0.08
                        onExited:  stateLayer.opacity = 0
                        onPressed: stateLayer.opacity = 0.12
                        onReleased: stateLayer.opacity = containsMouse ? 0.08 : 0

                        onClicked: {
                            // Si ya es el activo, limpia la selección manual
                            // para volver a la heurística automática.
                            if (Services.MprisService.selectedPlayer === chipWrapper.player)
                                Services.MprisService.selectedPlayer = null
                            else
                                Services.MprisService.selectedPlayer = chipWrapper.player
                        }
                    }
                }
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
