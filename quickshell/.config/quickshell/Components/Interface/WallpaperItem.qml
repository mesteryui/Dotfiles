import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick.Effects
import "../../Core"
import "../../Core/Services" as Services
import "../"

Rectangle {
    id: delegateRoot
    property var modelData

    readonly property bool isSelected: ListView.isCurrentItem

    width: 280
    height: 200
    radius: 16
    clip: true

    // M3: surface tokens según nivel de elevación
    color: isSelected ? Colors.md3.surface_container_highest : Colors.md3.surface_container_low

    // M3: borde primario solo cuando está seleccionado
    border.width: isSelected ? 2 : 0
    border.color: Colors.md3.primary

    Behavior on border.width {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    // M3 elevación: sombra más pronunciada al seleccionar
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Colors.md3.shadow
        shadowBlur: isSelected ? 0.8 : 0.4
        shadowVerticalOffset: isSelected ? 4 : 2
        shadowHorizontalOffset: 0
        blurMax: 16
        shadowOpacity: isSelected ? 0.25 : 0.08

        Behavior on shadowOpacity {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        Behavior on shadowVerticalOffset {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }

    // M3: escala sutil (el badge ya comunica selección)
    scale: isSelected ? 1.02 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuart
        }
    }

    // Placeholder mientras carga
    MaterialIcon {
        anchors.centerIn: parent
        icon: "image"
        size: 32
        color: Colors.md3.on_surface_variant
        opacity: 0.3
        visible: wallpaperPreview.status !== Image.Ready
    }

    // Imagen con máscara redondeada
    Rectangle {
        id: imageMask
        anchors.fill: parent
        radius: delegateRoot.radius
        color: "transparent"

        ClippingRectangle {
            anchors.fill: parent
            radius: delegateRoot.radius
            border.color: Colors.md3.primary
            border.width: isSelected ? 1 : 0
            color: "transparent"
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
        // M3 state layer: tinte primario sobre imagen al seleccionar
        Rectangle {
            anchors.fill: parent
            radius: delegateRoot.radius
            color: Colors.md3.primary
            opacity: isSelected ? 0.08 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }

        // M3 state layer: hover
        Rectangle {
            anchors.fill: parent
            radius: delegateRoot.radius
            color: Colors.md3.on_surface
            opacity: hoverArea.containsMouse ? 0.08 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    // M3 badge de selección — esquina superior derecha
    Rectangle {
        id: selectionBadge
        anchors {
            top: parent.top
            right: parent.right
            margins: 10
        }
        width: 28
        height: 28
        radius: 14

        color: Colors.md3.primary_container
        border.width: 2
        border.color: Colors.md3.primary

        opacity: isSelected ? 1 : 0
        scale: isSelected ? 1 : 0.4

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuart
            }
        }
        // OutBack da el "pop" característico de M3
        Behavior on scale {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutBack
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            icon: "check"
            size: 16
            color: Colors.md3.on_primary_container
        }
    }
}
