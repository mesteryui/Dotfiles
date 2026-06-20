import Quickshell.Services.Mpris
import qs.Core.Services as Services
import qs.Core
import Quickshell
import QtQuick
import qs.Components
Item {
    id: root
    property bool isHovered: false
    property var player: Services.MprisService.currentMprisPlayer
            implicitWidth: layout.childrenRect.width
            implicitHeight: 30
            Row {
                id: layout
                x: 12
                spacing: 5
                anchors.centerIn: parent
                visible: true

                Text {
                    id: titleText
                    text: root.player?.trackTitle ?? Services.I18nService.getTranslation("media.no_media")
                    color: Colors.md3.on_surface
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                    font.pixelSize: 14
                    scale: isHovered ? 1.08 : 1.00
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, 150)
                    Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing: Easing.OutQuad
                    }
                }

            }
            ButtonIcon {
                iconSize: 20
                iconName: "skip_previous"
                enabled: Services.MprisService.hasPlayer
                onClicked: Services.MprisService.previousTrack()
            }
            ButtonIcon {
                iconSize: 20
                iconName: Services.MprisService.isPlaying
                ? "pause"
                : "play_arrow"
                enabled: Services.MprisService.hasPlayer
                onClicked: Services.MprisService.togglePlaying()
            }
            ButtonIcon {
                iconSize: 20
                iconName: "skip_next"
                enabled: Services.MprisService.hasPlayer
                onClicked: {
                    console.log("next button clicked, hasPlayer:", Services.MprisService.hasPlayer);
                    Services.MprisService.nextTrack();
                }
            }
        }
    }