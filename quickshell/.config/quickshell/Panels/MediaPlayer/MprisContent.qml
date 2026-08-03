// MprisContent — Content
// Toda la UI del popup de media. Sin fondos ni sombras.
// Expone sliderDragging para que el Wrapper gestione los timers.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import QtQuick.Controls.Material
import Quickshell.Widgets
import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import Quickshell.Services.Mpris

Item {
    id: root

    property string artURL: ""

    // ── API con el Wrapper ────────────────────────────────────
    required property real currentPosition
    signal seekRequested(real newPosition)

    // El Wrapper lo consulta en sus Timers y Connections
    readonly property bool sliderDragging: progressSlider.pressed

    readonly property bool multiPlayer: Services.MprisService.players.length > 1

    implicitHeight: header.implicitHeight + controls.implicitHeight + (multiPlayer ? playerSelector.implicitHeight : 0)

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
            color: Qt.alpha(Appearance.md3.primary_container, 0.6)
        }

        // Arte de la pista recortado al radio del panel
        ClippingWrapperRectangle {
            anchors.fill: parent
            radius: 20
            color: "transparent"
            
            
            Image {
                id: artImage
                anchors.fill: parent
                source: root.artURL
                fillMode: Image.PreserveAspectCrop
                opacity: 0.3
                z: 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                    }
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
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Qt.tint(Appearance.md3.surface, Qt.alpha(Appearance.md3.primary, 0.08))
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
                text: Services.MprisService.activePlayer?.trackTitle ?? Services.I18nService.getTranslation("media.no_media")
                font.pixelSize: Appearance.font.pixelSize.title
                font.variableAxes: Appearance.font.variableAxes.title
                color: Appearance.md3.on_surface
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: Services.MprisService.activePlayer?.trackArtist || Services.MprisService.activePlayer?.trackAlbumArtist || ""
                font.pixelSize: 12
                color: Appearance.md3.on_surface_variant
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
                color: Appearance.md3.on_surface_variant
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.formatTime(Services.MprisService.activePlayer?.length ?? 0)
                font.pixelSize: 11
                font.family: Services.ConfigService.configs.appearence.monospace
                color: Appearance.md3.on_surface_variant
            }
        }

        // Slider de progreso
        Slider {
            id: progressSlider
            Material.accent: Appearance.md3.primary
            Material.background: Appearance.md3.background
            Material.foreground: Appearance.md3.on_background

            width: parent.width - parent.leftPadding - parent.rightPadding
            from: 0.0
            to: 1.0

            onMoved: root.seekRequested(value * (Services.MprisService.activePlayer?.length ?? 0))
        }

        Binding {
            target: progressSlider
            property: "value"
            value: (Services.MprisService.activePlayer?.length ?? 0) > 0 ? Math.min(1.0, root.currentPosition / Services.MprisService.activePlayer.length) : 0.0
            when: !progressSlider.pressed // Detiene la sobrescritura mientras arrastras
            restoreMode: Binding.RestoreBinding
        }

        // Botones prev / play / next
        RowLayout {
            width: parent.width - parent.leftPadding - parent.rightPadding
            spacing: 0
            implicitHeight: 44

            Item {
                Layout.fillWidth: true
            }

            ButtonIcon {
                iconSize: 20
                iconName: "skip_previous"
                enabled: Services.MprisService.activePlayer != null
                onClicked: Services.MprisService.previous()
            }

            // Botón play/pause
            Item {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                Layout.leftMargin: 8
                Layout.rightMargin: 8

                Rectangle {
                    anchors.fill: parent
                    radius: 22
                    color: Appearance.md3.primary_container
                }

                ButtonIcon {
                    anchors.centerIn: parent
                    iconSize: 22
                    iconName: Services.MprisService.isPlaying ? "pause" : "play_arrow"
                    enabled: Services.MprisService.activePlayer != null
                    iconColor: Appearance.md3.on_primary_container
                    onClicked: Services.MprisService.togglePlaying()
                }
            }

            ButtonIcon {
                iconSize: 20
                iconName: "skip_next"
                enabled: Services.MprisService.activePlayer != null
                onClicked: Services.MprisService.next()
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    // ── Selector de reproductor ───────────────────────────────
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

                delegate: WrapperMouseArea {
                    id: chipWrapper

                    required property var modelData
                    property MprisPlayer player: modelData

                    readonly property bool isActive: Services.MprisService.activePlayer === player

                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        if (Services.MprisService.activePlayer === chipWrapper.player)
                            Services.MprisService.setActivePlayer(null);
                        else
                            Services.MprisService.setActivePlayer(chipWrapper.player);
                    }

                    // Fondo del chip interactivo
                    Rectangle {
                        implicitWidth: chipLayout.implicitWidth + 24
                        implicitHeight: 28
                        radius: 9999
                        color: chipWrapper.isActive ? Appearance.md3.primary_container : "transparent"
                        border.width: chipWrapper.isActive ? 0 : 1
                        border.color: Appearance.md3.outline_variant

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        // Icono + Nombre del reproductor
                        RowLayout {
                            id: chipLayout
                            anchors.centerIn: parent
                            spacing: 6

                            IconImage {
                                implicitWidth: 16
                                implicitHeight: 16
                                source: Quickshell.iconPath(chipWrapper.player.desktopEntry,true)
                            }

                            StyledText {
                                text: chipWrapper.player.identity ?? chipWrapper.player.dbusName
                                font.family: Services.ConfigService.configs.appearence.fontSans
                                font.pixelSize: 11
                                color: chipWrapper.isActive ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Utilidades ────────────────────────────────────────────
    function formatTime(seconds: real): string {
        const totalSec = Math.floor(seconds);
        const h = Math.floor(totalSec / 3600);
        const m = Math.floor((totalSec % 3600) / 60);
        const s = totalSec % 60;

        if (h > 0) {
            return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
        }
        return m + ":" + String(s).padStart(2, "0");
    }
}