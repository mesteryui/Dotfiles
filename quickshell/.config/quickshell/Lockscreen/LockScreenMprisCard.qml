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
    readonly property real progress: trackLength > 0 ? Math.min(1, Math.max(0, mprisPosition / trackLength)) : 0

    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    function withAlpha(hexColor, alphaValue) {
        var c = Qt.color(hexColor);
        return Qt.rgba(c.r, c.g, c.b, alphaValue);
    }

    function formatTime(seconds) {
        if (isNaN(seconds) || seconds < 0)
            return "0:00";
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const ss = String(s % 60).padStart(2, "0");
        return `${m}:${ss}`;
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
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: (MprisService.activeTrack && MprisService.activeTrack.artist) ? MprisService.activeTrack.artist : ""
                    color: Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                M3ProgressBar {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    value: root.progress
                    accentColor: Appearance.md3.primary
                    implicitHeight: 5
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
                            size: 22
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

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: root.formatTime(root.mprisPosition) + " / " + root.formatTime(root.trackLength)
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                }
            }
        }
    }

    MultiEffect {
        anchors.fill: mprisBg
        source: mprisBg
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowOpacity: 0.20
        shadowBlur: 0.9
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
    }
}
