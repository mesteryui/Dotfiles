pragma ComponentBehavior: Bound

import qs.Primitives
import qs.Core
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: root

    required property QsMenuHandle menu

    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: 220
    implicitHeight: menuColumn.implicitHeight + 20

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => root.visible = false)
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Appearance.md3.surface
        border.color: Appearance.md3.outline
        border.width: 1

        // QsMenuOpener lee los hijos del handle
        QsMenuOpener {
            id: opener

            menu: root.menu
        }

        Column {
            id: menuColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }

            spacing: 2

            Repeater {
                model: opener.children

                delegate: Item {
                    id: itemDelegate

                    required property QsMenuEntry modelData

                    width: menuColumn.width
                    implicitHeight: (itemDelegate.modelData?.isSeparator ?? false) ? 5 : 36

                    // Separador
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 1
                        visible: itemDelegate.modelData?.isSeparator ?? false
                        color: Appearance.md3.outline_variant
                        opacity: 0.5
                    }

                    // Item normal
                    Rectangle {
                        id: itemRoot

                        anchors.fill: parent
                        visible: !(itemDelegate.modelData?.isSeparator ?? false)
                        radius: 8
                        color: itemMouse.containsMouse ? Appearance.md3.primary : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }

                        opacity: (itemDelegate.modelData?.enabled ?? true) ? 1.0 : 0.4

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 8

                            // Icono (si tiene)
                            Image {
                                visible: (itemDelegate.modelData?.icon ?? "") !== ""
                                source: itemDelegate.modelData?.icon ?? ""
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                sourceSize.width: 16
                                sourceSize.height: 16
                                fillMode: Image.PreserveAspectFit
                            }

                            // Texto
                            StyledText {
                                Layout.fillWidth: true
                                text: itemDelegate.modelData?.text ?? ""
                                color: itemMouse.containsMouse ? Appearance.md3.on_primary : Appearance.md3.on_surface
                                font.pixelSize: 13
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }
                            }

                            // Indicador de submenú
                            MaterialIcon {
                                visible: itemDelegate.modelData?.hasChildren ?? false
                                text: "chevron_right"
                                color: Appearance.md3.on_surface_variant
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }

                            // Checkbox / radio
                            Rectangle {
                                visible: (itemDelegate.modelData?.buttonType ?? QsMenuButtonType.None) !== QsMenuButtonType.None
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                radius: (itemDelegate.modelData?.buttonType ?? QsMenuButtonType.None) === QsMenuButtonType.Radio ? 8 : 4
                                color: (itemDelegate.modelData?.checkState ?? Qt.Unchecked) === Qt.Checked ? Appearance.md3.primary : "transparent"
                                border.color: Appearance.md3.outline
                                border.width: 1
                            }
                        }

                        MouseArea {
                            id: itemMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: (itemDelegate.modelData?.enabled ?? false) && !(itemDelegate.modelData?.isSeparator ?? false)
                            onClicked: {
                                const entry = itemDelegate.modelData;
                                if (!entry)
                                    return;
                                if (entry.hasChildren) {
                                    const pos = itemRoot.mapToGlobal(itemRoot.width, 0);
                                    entry.display(root.QsWindow.window, pos.x, pos.y);
                                } else {
                                    entry.triggered();
                                    root.visible = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
