// LauncherModeBar — chips de modo, grupos de emoji y breadcrumb del sistema.
// Extraído de AppLauncher.qml. `controller` es el PanelWindow del launcher.
// La escritura del campo se delega con pickTodo/System/Mode.
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import M3Shapes

ColumnLayout {
    id: root

    property var controller

    signal pickTodo
    signal pickSystem
    signal pickMode(string selectorChar)

    spacing: 10

    Item {
        Layout.fillWidth: true
        implicitHeight: 32

        Flickable {
            id: modeScroller

            anchors.fill: parent
            contentWidth: modeRow.implicitWidth
            contentHeight: 32
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width

        // Rueda vertical -> desplazamiento horizontal.
        WheelHandler {
            orientation: Qt.Vertical
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const d = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                const maxX = Math.max(0, modeScroller.contentWidth - modeScroller.width);
                modeScroller.contentX = Math.min(maxX, Math.max(0, modeScroller.contentX - d));
            }
        }

        Row {
            id: modeRow

            spacing: 6
            height: 32

            Repeater {
                id: modeRepeater

                model: controller.modes
                delegate: Rectangle {
                    id: chipRect

                    required property var modelData
                    required property int index

                    property bool isActive: controller.activeMode === modelData.modeId

                    // Ancho según contenido: sin aplastamiento.
                    width: Math.max(64, chipRow.implicitWidth + 26)
                    height: 30
                    // Spec M3 assist-chip: contenedor small (8dp).
                    radius: Appearance.shape.small
                    color: isActive ? Appearance.md3.secondary_container : "transparent"
                    border.width: isActive ? 0 : 1
                    border.color: Appearance.md3.outline_variant

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: 6

                        // Check de filter-chip M3: solo en el modo activo.
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "check"
                            size: 16
                            color: Appearance.md3.on_secondary_container
                            visible: chipRect.isActive
                        }

                        // Badge expresivo con la forma-identidad del modo.
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 22
                            implicitHeight: 22

                            MaterialShape {
                                anchors.fill: parent
                                shape: controller.modeShape(modelData.modeId)
                                animationDuration: 300
                                color: chipRect.isActive ? Appearance.md3.primary : Appearance.md3.surface_container_highest

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    icon: controller.modeIcon(modelData.modeId)
                                    size: 12
                                    color: chipRect.isActive ? Appearance.md3.on_primary : Appearance.md3.on_surface_variant
                                }
                            }
                        }

                        StyledText {
                            id: chipText

                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.parent.width - 50)
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            // Carácter selector del menú entre corchetes: teclearlo cambia de menú.
                            text: (modelData.selectorChar !== "" ? "[" + modelData.selectorChar + "] " : "") + controller.modeLabel(modelData.modeId)
                            font.pixelSize: 12
                            color: chipRect.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.modeId === "todo") {
                                pickTodo();
                            } else if (modelData.modeId === "system") {
                                pickSystem();
                            } else {
                                pickMode(modelData.selectorChar);
                            }
                        }
                    }
                }
            }
        }

        // Mantiene visible el chip activo al cambiar de modo.
        Connections {
            target: launcher
            function onActiveModeChanged() {
                Qt.callLater(() => {
                    let x = 0;
                    for (let i = 0; i < modeRepeater.count; i++) {
                        const item = modeRepeater.itemAt(i);
                        if (controller.modes[i].modeId === controller.activeMode) {
                            const maxX = Math.max(0, modeScroller.contentWidth - modeScroller.width);
                            if (x < modeScroller.contentX)
                                modeScroller.contentX = x;
                            else if (x + (item ? item.width : 0) > modeScroller.contentX + modeScroller.width)
                                modeScroller.contentX = Math.min(maxX, Math.max(0, x + (item ? item.width : 0) - modeScroller.width));
                            break;
                        }
                        x += (item ? item.width : 0) + modeRow.spacing;
                    }
                });
            }
        }

        // Fade trailing: pista de scroll horizontal (spec tabs
        // scrollables). Solo con desborde pendiente a la derecha.
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 32
            visible: modeScroller.contentWidth > modeScroller.width + 1 && modeScroller.contentX < (modeScroller.contentWidth - modeScroller.width - 1)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Appearance.md3.surface
                }
            }
        }
    }
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6
        visible: controller.activeMode === "emoji"

        Repeater {
            model: controller.emojiGroups
            delegate: Rectangle {
                required property var modelData
                required property int index

                property bool isActive: controller.emojiActiveGroup() === modelData.id

                width: Math.max(56, groupChipText.implicitWidth + 30)
                height: 26
                // Spec M3 assist-chip: contenedor small (8dp).
                radius: Appearance.shape.small
                color: isActive ? Appearance.md3.secondary_container : "transparent"
                border.width: isActive ? 0 : 1
                border.color: Appearance.md3.outline_variant

                Row {
                    anchors.centerIn: parent
                    spacing: Appearance.spacing.xs

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: modelData.icon || "circle"
                        size: 14
                        color: parent.parent.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                    }
                    StyledText {
                        id: groupChipText

                        anchors.verticalCenter: parent.verticalCenter
                        // Sin conteo: chips compactos de una fila.
                        text: modelData.label
                        font.pixelSize: 12
                        color: parent.parent.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.toggleEmojiGroup(modelData.id)
                }
            }
        }
    }

    Row {
        Layout.fillWidth: true
        spacing: Appearance.spacing.xs
        visible: controller.activeMode === "system"

        Repeater {
            id: crumbRepeater

            model: controller.systemTrail()

            delegate: Rectangle {
                required property var modelData
                required property int index

                property bool isLast: index === crumbRepeater.count - 1

                height: 26
                width: crumbLabel.implicitWidth + 22
                radius: Appearance.shape.full
                color: isLast ? Appearance.md3.primary_container : "transparent"

                StyledText {
                    id: crumbLabel

                    anchors.centerIn: parent
                    text: (index > 0 ? "› " : "") + modelData.title
                    font.pixelSize: 12
                    color: parent.isLast ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: controller.goSection(modelData.sectionId)
                }
            }
        }
    }
}
