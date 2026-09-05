// --- AudioPopupContent ---
// Contenido del popup de audio: botón grande de mute/estado, selector de altavoz,
// slider de volumen de salida y slider de volumen de micrófono.
pragma ComponentBehavior: Bound
import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: 300
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 16

        // --- Botón grande de estado / mute ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                id: bigButton

                implicitWidth: 72
                implicitHeight: 72
                radius: Appearance.shape.large
                color: Services.AudioService.muted ? Appearance.md3.surface_container_highest : Appearance.md3.primary_container

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: Services.AudioService.materialIcon
                    size: 36
                    color: Services.AudioService.muted ? Appearance.md3.on_surface_variant : Appearance.md3.on_primary_container
                }

                Rectangle {
                    id: bigButtonStateLayer

                    anchors.fill: parent
                    radius: parent.radius
                    color: Appearance.md3.on_surface
                    opacity: 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: bigButtonStateLayer.opacity = 0.08
                    onExited: bigButtonStateLayer.opacity = 0
                    onPressed: bigButtonStateLayer.opacity = 0.12
                    onReleased: bigButtonStateLayer.opacity = containsMouse ? 0.08 : 0
                    onClicked: Services.AudioService.toggleMuted()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: Services.AudioService.muted ? "Silenciado" : Math.round(Services.AudioService.volume * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.bold: true
                    color: Appearance.md3.on_surface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Services.AudioService.deviceLabel(Services.AudioService.sink)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.md3.on_surface_variant
                    elide: Text.ElideRight
                }
            }
        }

        // --- Slider de volumen de salida ---
        ControlSlider {
            Layout.fillWidth: true
            iconName: Services.AudioService.materialIcon
            value: Services.AudioService.volume
            accentColor: Appearance.md3.primary
            onMoved: val => Services.AudioService.setVolume(val)
            onIconClicked: Services.AudioService.toggleMuted()
        }

        // --- Selector de altavoz ---
        StyledText {
            text: "Salida"
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.bold: true
            color: Appearance.md3.on_surface_variant
            Layout.leftMargin: 4
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: Services.AudioService.sinks

                delegate: Rectangle {
                    id: sinkRow

                    required property var modelData

                    readonly property bool selected: Services.AudioService.sink === sinkRow.modelData

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Appearance.shape.small
                    color: sinkRow.selected ? Appearance.md3.secondary_container : "transparent"

                    Rectangle {
                        id: sinkStateLayer

                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.md3.on_surface
                        opacity: 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        MaterialIcon {
                            icon: "speaker"
                            size: Appearance.font.pixelSize.large
                            color: sinkRow.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Services.AudioService.deviceLabel(sinkRow.modelData)
                            elide: Text.ElideRight
                            color: sinkRow.selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                        }

                        MaterialIcon {
                            visible: sinkRow.selected
                            icon: "check"
                            size: Appearance.font.pixelSize.large
                            color: Appearance.md3.on_secondary_container
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: sinkStateLayer.opacity = 0.08
                        onExited: sinkStateLayer.opacity = 0
                        onPressed: sinkStateLayer.opacity = 0.12
                        onReleased: sinkStateLayer.opacity = containsMouse ? 0.08 : 0
                        onClicked: Services.AudioService.setSink(sinkRow.modelData)
                    }
                }
            }
        }

        // --- Divisor ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.md3.outline_variant
        }

        // --- Slider de micrófono ---
        StyledText {
            text: "Micrófono"
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.bold: true
            color: Appearance.md3.on_surface_variant
            Layout.leftMargin: 4
        }

        ControlSlider {
            Layout.fillWidth: true
            iconName: Services.AudioService.micMaterialIcon
            value: Services.AudioService.micVolume
            accentColor: Appearance.md3.primary
            onMoved: val => Services.AudioService.setMicVolume(val)
            onIconClicked: Services.AudioService.toggleMicMuted()
        }
    }
}
