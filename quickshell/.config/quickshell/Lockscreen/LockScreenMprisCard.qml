import qs.Core
import qs.Core.Services
import qs.Primitives
import qs.Components
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root

    implicitWidth: mprisContent.childrenRect.width + 20
    implicitHeight: 100
    visible: MprisService.activePlayer !== null
    opacity: visible ? 1 : 0

    property real mprisPosition: 0

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
        radius: Appearance.shape.normal
        color: root.withAlpha(Appearance.md3.surface_container_high, 0.55)
        border.width: 1
        border.color: root.withAlpha(Appearance.md3.outline_variant, 0.6)

        RowLayout {
            id: mprisContent
            anchors {
                centerIn: parent
                margins: 20
            }

            spacing: 12

            // Carátula de la canción
            ClippingRectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                radius: Appearance.shape.small
                color: Appearance.md3.surface_container_highest

                Image {
                    id: mprisArt

                    anchors.fill: parent
                    source: (MprisService.activeTrack && MprisService.activeTrack.artUrl) ? MprisService.activeTrack.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: source !== "" && status === Image.Ready
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "music_note"
                    size: 26
                    color: Appearance.md3.on_surface_variant
                    visible: !mprisArt.visible
                }
            }

            // Info de pista + controles
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: (MprisService.activeTrack && MprisService.activeTrack.title) ? MprisService.activeTrack.title : ""
                    color: Appearance.md3.on_surface
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: (MprisService.activeTrack && MprisService.activeTrack.artist) ? MprisService.activeTrack.artist : ""
                    color: Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.topMargin: 4
                    spacing: 2

                    ButtonIcon {
                        iconName: "skip_previous"
                        enabled: MprisService.canGoPrevious
                        onClicked: MprisService.previous()
                    }
                    ButtonIcon {
                        iconName: MprisService.isPlaying ? "pause" : "play_arrow"
                        enabled: MprisService.canTogglePlaying
                        onClicked: MprisService.togglePlaying()
                    }
                    ButtonIcon {
                        iconName: "skip_next"
                        enabled: MprisService.canGoNext
                        onClicked: MprisService.next()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: root.formatTime(root.mprisPosition) + " / " + root.formatTime((MprisService.activePlayer && MprisService.activePlayer.length) ? MprisService.activePlayer.length : 0)
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
        shadowOpacity: 0.18
        shadowBlur: 0.8
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
    }
}
