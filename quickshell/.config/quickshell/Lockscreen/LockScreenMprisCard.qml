import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

// Tarjeta multimedia M3 expresiva tipo Pixel: contenedor tonal redondeado,
// carátula, progreso lineal y control principal relleno.
Item {
    id: root

    implicitWidth: 400
    implicitHeight: 132
    visible: MprisService.activePlayer !== null
    opacity: visible ? 1 : 0

    property real mprisPosition: 0
    readonly property real trackLength: (MprisService.activePlayer && MprisService.activePlayer.length) ? MprisService.activePlayer.length : 0

    // Posición optimista post-seek (igual que Panels/MediaPlayer/MprisSubwindow):
    // el player aplica el seek de forma asíncrona; mientras tanto manda lo pedido.
    property real seekTarget: -1
    property double seekTargetUntil: 0
    readonly property real effectivePosition: root.seekTarget >= 0 ? root.seekTarget : root.mprisPosition

    Timer {
        interval: 1000
        running: root.seekTarget >= 0
        repeat: false
        onTriggered: root.seekTarget = -1
    }

    onMprisPositionChanged: {
        if (root.seekTarget >= 0 && (root.mprisPosition >= root.seekTarget - 1.0 || Date.now() >= root.seekTargetUntil))
            root.seekTarget = -1;
    }

    Connections {
        target: MprisService

        // Cambio de pista: invalida el seek pendiente (igual que el popup).
        function onTrackChanged() {
            root.seekTarget = -1;
        }
    }

    function requestSeek(newPosition: real) {
        const p = MprisService.activePlayer;
        if (!p || !(p.canSeek || p.canControl))
            return;
        try {
            p.position = newPosition;
        } catch (e) {
        }
        root.seekTarget = newPosition;
        root.seekTargetUntil = Date.now() + 1000;
    }

    Behavior on opacity {
        NumberAnimation { duration: Appearance.motion.short4 }
    }

    function withAlpha(hexColor, alphaValue) {
        var c = Qt.color(hexColor);
        return Qt.rgba(c.r, c.g, c.b, alphaValue);
    }

    Rectangle {
        id: mprisBg

        anchors.fill: parent
        radius: Appearance.shape.verylarge
        color: root.withAlpha(Appearance.md3.surface_container_high, 0.78)
        border.width: 1
        border.color: root.withAlpha(Appearance.md3.outline_variant, 0.5)

        RowLayout {
            id: mprisContent
            anchors {
                fill: parent
                leftMargin: 16
                rightMargin: 16
                topMargin: 14
                bottomMargin: 14
            }

            spacing: 14

            // Carátula de la canción
            ClippingRectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.shape.large
                color: Appearance.md3.surface_container_highest

                Image {
                    id: mprisArt

                    anchors.fill: parent
                    source: (MprisService.activeTrack && MprisService.activeTrack.artUrl) ? MprisService.activeTrack.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    // Caja de 64px: la carátula suele venir a 500px+,
                    // decodificarla entera es memoria/tiempo gratis.
                    sourceSize.width: 128
                    sourceSize.height: 128
                    visible: source !== "" && status === Image.Ready
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "music_note"
                    size: 28
                    color: Appearance.md3.on_surface_variant
                    visible: !mprisArt.visible
                }
            }

            // Info de pista + progreso + controles
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    text: (MprisService.activeTrack && MprisService.activeTrack.title) ? MprisService.activeTrack.title : ""
                    color: Appearance.md3.on_surface
                    font.pixelSize: Appearance.typeScale.titleSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: (MprisService.activeTrack && MprisService.activeTrack.artist) ? MprisService.activeTrack.artist : ""
                    color: Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.typeScale.labelMedium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // Seekbar unificado (Primitives/MprisSeekBar): mismo gesto y
                // estados que el popup multimedia, con fill ondulado M3E.
                MprisSeekBar {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    wavy: true
                    position: root.effectivePosition
                    length: root.trackLength
                    canSeek: (MprisService.activePlayer?.canSeek || MprisService.activePlayer?.canControl) ?? false
                    onSeekRequested: newPosition => root.requestSeek(newPosition)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 2

                    ButtonIcon {
                        iconName: "skip_previous"
                        iconSize: 22
                        enabled: MprisService.canGoPrevious
                        onClicked: MprisService.previous()
                    }
                    // Play / pause principal en contenedor tonal estilo Pixel
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: width / 2
                        color: Appearance.md3.primary_container
                        opacity: MprisService.canTogglePlaying ? 1 : 0.5

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: MprisService.isPlaying ? "pause" : "play_arrow"
                            size: 24
                            color: Appearance.md3.on_primary_container
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: MprisService.canTogglePlaying
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MprisService.togglePlaying()
                        }
                    }
                    ButtonIcon {
                        iconName: "skip_next"
                        iconSize: 22
                        enabled: MprisService.canGoNext
                        onClicked: MprisService.next()
                    }
                }
            }
        }
    }

    // Elevación MD3: source se asigna en onCompleted para evitar warning
    // "ShaderEffect: 'source' does not have a matching property"
    MultiEffect {
        id: mprisShadow
        anchors.fill: mprisBg
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowOpacity: Appearance.elevation4.opacity
        shadowBlur: Appearance.elevation4.blur
        shadowVerticalOffset: Appearance.elevation4.offsetY
        shadowHorizontalOffset: 0
        Component.onCompleted: mprisShadow.source = mprisBg
    }
}
