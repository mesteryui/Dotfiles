import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool isHovered: false
        property var player: Services.MprisService.activePlayer
            implicitWidth: layout.width
            implicitHeight: 30

            RowLayout {
                id: layout

                x: 12
                spacing: 3
                anchors.centerIn: parent
                visible: true

                StyledText {
                    id: titleText

                    text: root.player?.trackTitle ?? Services.I18nService.getTranslation("media.empty")
                    color: Appearance.md3.on_surface
                    Layout.alignment: Qt.AlignVCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    Layout.preferredWidth: Math.min(implicitWidth, 150)

            }
            ButtonIcon {
                iconSize: Appearance.typeScale.bodyLarge
                iconName: "skip_previous"
                enabled: Services.MprisService.activePlayer != null
                onClicked: Services.MprisService.previous()
                Layout.alignment: Qt.AlignVCenter
            }
            ButtonIcon {
                iconSize: Appearance.typeScale.bodyLarge
                iconName: Services.MprisService.isPlaying
                ? "pause"
                : "music_note"
                enabled: Services.MprisService.activePlayer != null
                onClicked: Services.MprisService.togglePlaying()
                Layout.alignment: Qt.AlignVCenter
            }
            ButtonIcon {
                iconSize: Appearance.typeScale.bodyLarge
                iconName: "skip_next"
                enabled: Services.MprisService.activePlayer != null
                onClicked: Services.MprisService.next()
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }