import qs.Core.Services as Services
import QtQuick.Layouts
import qs.Core
import QtQuick
import qs.Primitives
Item {
    id: root
    property bool isHovered: false
        property var player: Services.MprisService.currentMprisPlayer
            implicitWidth: layout.childrenRect.width
            implicitHeight: 30
            RowLayout {
                id: layout
                x: 12
                spacing: 3
                anchors.centerIn: parent
                visible: true

                StyledText {
                    id: titleText
                    text: root.player?.trackTitle ?? Services.I18nService.getTranslation("media.no_media")
                    color: Appearance.md3.on_surface
                    Layout.alignment: Qt.AlignVCenter
                    scale: root.isHovered ? 1.04 : 1.00
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.preferredWidth: Math.min(implicitWidth, 150)
                    Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing: Easing.OutQuad
                    }
                }

            }
            ButtonIcon {
                iconSize: Appearance.font.pixelSize.normal
                iconName: "skip_previous"
                enabled: Services.MprisService.hasPlayer
                onClicked: Services.MprisService.previousTrack()
                Layout.alignment: Qt.AlignVCenter
            }
            ButtonIcon {
                iconSize: Appearance.font.pixelSize.normal
                iconName: Services.MprisService.isPlaying
                ? "pause"
                : "play_arrow"
                enabled: Services.MprisService.hasPlayer
                onClicked: Services.MprisService.togglePlaying()
                Layout.alignment: Qt.AlignVCenter
            }
            ButtonIcon {
                iconSize: Appearance.font.pixelSize.normal
                iconName: "skip_next"
                enabled: Services.MprisService.hasPlayer
                onClicked: {
                    console.log("next button clicked, hasPlayer:", Services.MprisService.hasPlayer);
                    Services.MprisService.nextTrack();
                }
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }