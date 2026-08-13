// MprisContent — Content
// Toda la UI del popup de media. Sin fondos ni sombras (las gestiona el Wrapper).
// Estilo: 70% Material You (tokens, tonal containers, state layers) + 30% GNOME/Adwaita
// (tarjeta plana con borde fino en vez de degradado, thumbnail cuadrado en vez de
// fondo a sangre, slider ultra-delgado, botón de play grande como foco único).
// Expone sliderDragging para que el Wrapper gestione los timers.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
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
    readonly property bool hasArt: root.artURL !== ""

    // 14 = margen superior de header · 12 = margen superior de divider
    implicitHeight: 14 + header.implicitHeight + 12 + divider.implicitHeight + controls.implicitHeight + (multiPlayer ? playerSelector.implicitHeight : 0)

    // ── Cabecera: tarjeta plana con thumbnail + título/artista ─
    // (Adwaita "now playing" row en vez del header a sangre con degradado)
    Item {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 14
        }
        implicitHeight: 72

        // Fondo tonal plano, sin degradados: borde fino en vez de sombra pesada
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Appearance.md3.surface_container_high
            border.width: 1
            border.color: Qt.alpha(Appearance.md3.outline_variant, 0.5)
        }

        RowLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 12

            // Thumbnail cuadrado con esquinas redondeadas (no full-bleed)
            Item {
                id: artThumb
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Appearance.md3.primary_container
                    visible: !artImage.visible || artImage.status !== Image.Ready

                    ButtonIcon {
                        anchors.centerIn: parent
                        iconSize: 22
                        iconName: "music_note"
                        enabled: false
                        iconColor: Appearance.md3.on_primary_container
                    }
                }

                ClippingWrapperRectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: root.artURL
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        asynchronous: true
                        visible: root.hasArt && status === Image.Ready
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }
                    }
                }
            }

            // Título y artista
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: Services.MprisService.activePlayer?.trackTitle ?? Services.I18nService.getTranslation("media.no_media")
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Appearance.md3.on_surface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Services.MprisService.activePlayer?.trackArtist || Services.MprisService.activePlayer?.trackAlbumArtist || ""
                    font.pixelSize: 12
                    color: Appearance.md3.on_surface_variant
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }
        }
    }

    // ── Separador fino (Adwaita usa hairlines en vez de degradados) ─
    Item {
        id: divider
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            margins: 14
            topMargin: 12
        }
        implicitHeight: 1

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Appearance.md3.outline_variant, 0.4)
        }
    }

    // ── Controles: slider y botones ───────────────────────────
    Column {
        id: controls
        anchors {
            top: divider.bottom
            left: parent.left
            right: parent.right
        }
        topPadding: 12
        bottomPadding: root.multiPlayer ? 8 : 16
        leftPadding: 16
        rightPadding: 16
        spacing: 6

        // Slider de progreso — pista ultra-delgada, sin caja Material,
        // el "pill track" es una convención GNOME/Adwaita habitual.
        Slider {
            id: progressSlider
            width: parent.width - parent.leftPadding - parent.rightPadding
            from: 0.0
            to: 1.0
            implicitHeight: 20

            onMoved: root.seekRequested(value * (Services.MprisService.activePlayer?.length ?? 0))

            background: Item {
                x: progressSlider.leftPadding
                y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                width: progressSlider.availableWidth
                height: 4

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: Qt.alpha(Appearance.md3.on_surface, 0.12)
                }

                Rectangle {
                    width: progressSlider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Appearance.md3.primary
                }
            }

            handle: Rectangle {
                x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                width: progressSlider.pressed || progressSlider.hovered ? 14 : 10
                height: width
                radius: width / 2
                color: Appearance.md3.primary

                Behavior on width {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }

        Binding {
            target: progressSlider
            property: "value"
            value: (Services.MprisService.activePlayer?.length ?? 0) > 0 ? Math.min(1.0, root.currentPosition / Services.MprisService.activePlayer.length) : 0.0
            when: !progressSlider.pressed // Detiene la sobrescritura mientras arrastras
            restoreMode: Binding.RestoreBinding
        }

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

        // Botones prev / play / next — el play grande es el único foco
        // visual fuerte (acento M3), prev/next quedan planos (Adwaita).
        RowLayout {
            width: parent.width - parent.leftPadding - parent.rightPadding
            spacing: 0
            implicitHeight: 56

            Item {
                Layout.fillWidth: true
            }

            ButtonIcon {
                iconSize: 20
                iconName: "skip_previous"
                enabled: Services.MprisService.activePlayer != null
                onClicked: Services.MprisService.previous()
            }

            // Botón play/pause — foco principal, relleno sólido y sombra sutil
            Item {
                id: playButtonWrap
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                MultiEffect {
                    source: playButtonBg
                    anchors.fill: playButtonBg
                    shadowEnabled: true
                    shadowColor: Appearance.md3.shadow
                    shadowOpacity: 0.16
                    shadowBlur: 0.6
                    shadowVerticalOffset: 2
                    shadowHorizontalOffset: 0
                }

                Rectangle {
                    id: playButtonBg
                    anchors.fill: parent
                    radius: 28
                    color: Appearance.md3.primary
                }

                ButtonIcon {
                    anchors.centerIn: parent
                    iconSize: 24
                    iconName: Services.MprisService.isPlaying ? "pause" : "play_arrow"
                    enabled: Services.MprisService.activePlayer != null
                    iconColor: Appearance.md3.on_primary
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
    // Chips planos con borde fino cuando no están activos: mezcla del
    // pill chip M3 con el look de "segmented toggle" de Adwaita.
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

        // Chips en fila; si hay muchos players, se limita el ancho y se
        // habilita scroll horizontal con Flickable en vez de desbordar.
        Flickable {
            id: chipsFlickable
            anchors {
                top: parent.top
                topMargin: 0
                horizontalCenter: parent.horizontalCenter
            }
            width: Math.min(chipsRow.implicitWidth, parent.width)
            height: chipsRow.implicitHeight
            contentWidth: chipsRow.implicitWidth
            contentHeight: chipsRow.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            interactive: contentWidth > width

            Row {
                id: chipsRow
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
                                    source: Quickshell.iconPath(chipWrapper.player.desktopEntry, true)
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
