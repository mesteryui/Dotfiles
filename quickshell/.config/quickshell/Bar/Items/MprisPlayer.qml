import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../Core/Services" as Services
import "../../Core"
import "../../Features/Subwindows"
import "../../Components"
import QtQuick.Layouts

Rectangle {
    id: root

    property var player: Services.MprisService.currentMprisPlayer
    implicitWidth: childrenRect.width + (12 * 2)
    implicitHeight: 30
    color: Colors.surface_container_high
    radius: 20

    // Helpers para no repetir la guardia null en cada binding

    MprisSubwindow {
        id: popup
        //anchor.window: root.QsWindow.window
        anchor.item: titleText          // ← ancla al texto
        anchor.margins.top: 30
        anchor.edges: Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom
        anchor.gravity: Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom
    }

    Row {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        visible: true

        Text {
            id: titleText
            text: root.player?.trackTitle ?? Services.I18nService.getTranslation("media.no_media")
            color: Colors.on_surface
            anchors.verticalCenter: parent.verticalCenter
            font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
            font.pixelSize: 14
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 150)
            scale: mouseManagment.pressed ? 1.10 : 1
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                    easing: Easing.OutQuad
                }
            }
            MouseArea {
                id: mouseManagment
                anchors.fill: parent
                enabled: Services.MprisService.hasPlayer
                cursorShape: Qt.PointingHandCursor
                onClicked: popup.visible = !popup.visible  // ← toggle del popup
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
