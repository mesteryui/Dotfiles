import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick.Effects
import ".."
import "../Services" as Services

Rectangle {
    id: delegateRoot
    property var modelData
    width: 280
    height: 200
    color: isSelected ? Colors.surface_container_highest : Colors.surface_container
    radius: 20
    clip: true
    border.width: isSelected ? 2 : 1
    border.color: isSelected ? Colors.outline_variant : "transparent"
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Colors.shadow
        shadowBlur: 1.0
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
        blurMax: 16
        shadowOpacity: isSelected ? 0.5 : 0.15
        Behavior on shadowOpacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }
    readonly property bool isSelected: ListView.isCurrentItem

    scale: isSelected ? 1.03 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuart
        }
    }

    Text {
        anchors.centerIn: parent
        text: "⌛️"
        font.pixelSize: 24
        opacity: 0.3
        visible: wallpaperPreview.status !== Image.Ready
    }
    Rectangle {
        id: imageMask
        anchors.fill: parent
        radius: delegateRoot.radius
        color: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {       // ← sustituye layer.smooth: true
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: imageMask.width
                    height: imageMask.height
                    radius: imageMask.radius
                }
            }
        }

        Image {
            id: wallpaperPreview
            anchors.fill: parent
            source: "file://" + model.filePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 560
            sourceSize.height: 400

            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
