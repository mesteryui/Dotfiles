pragma ComponentBehavior: Bound

import qs.Primitives
import qs.Core
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: root

    property QsMenuHandle menu: null

    signal dismissed

    onVisibleChanged: {
        if (!root.visible)
            root.dismissed();
    }

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
        // Spec M3 menus: contenedor extraSmall (4dp).
        radius: Appearance.shape.extraSmall
        color: Appearance.md3.surface
        border.color: Appearance.border.subtleOn(Appearance.md3.surface)
        border.width: Appearance.border.width

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
                margins: Appearance.spacing.small
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
                        opacity: 1.0
                    }

                    // Item normal
                    Rectangle {
                        id: itemRoot

                        anchors.fill: parent
                        visible: !(itemDelegate.modelData?.isSeparator ?? false)
                        radius: Appearance.shape.small
                        color: itemMouse.containsMouse ? Appearance.md3.primary : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.motion.veryFast
                            }
                        }

                        opacity: (itemDelegate.modelData?.enabled ?? true) ? 1.0 : 0.4

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: Appearance.spacing.medium
                                rightMargin: Appearance.spacing.medium
                            }
                            spacing: Appearance.spacing.small

                            // Icono (si tiene)
                            Image {
                                visible: (itemDelegate.modelData?.icon ?? "") !== ""
                                source: itemDelegate.modelData?.icon ?? ""
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                sourceSize.width: 16
                                sourceSize.height: 16
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectFit
                            }

                            // Texto
                            StyledText {
                                Layout.fillWidth: true
                                text: itemDelegate.modelData?.text ?? ""
                                color: itemMouse.containsMouse ? Appearance.md3.on_primary :
                                                                 Appearance.md3.on_surface
                                font.pixelSize: Appearance.typeScale.bodySmall
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.motion.veryFast
                                    }
                                }
                            }

                            // Indicador de submenú
                            MaterialIcon {
                                visible: itemDelegate.modelData?.hasChildren ?? false
                                icon: "chevron_right"
                                color: Appearance.md3.on_surface_variant
                                font.pixelSize: Appearance.typeScale.bodyLarge
                            }

                            // Checkbox / radio
                            Rectangle {
                                visible: (itemDelegate.modelData?.buttonType ?? QsMenuButtonType.None)
                                         !== QsMenuButtonType.None
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                radius: (itemDelegate.modelData?.buttonType ?? QsMenuButtonType.None)
                                        === QsMenuButtonType.Radio ? Appearance.shape.small :
                                                                     Appearance.shape.extraSmall
                                color: (itemDelegate.modelData?.checkState ?? Qt.Unchecked) === Qt.Checked
                                       ? Appearance.md3.primary : "transparent"
                                border.color: Appearance.border.strong
                                border.width: Appearance.border.width
                            }
                        }

                        MouseArea {
                            id: itemMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: (itemDelegate.modelData?.enabled ?? false) && !(itemDelegate.modelData
                                                                                     ?.isSeparator ?? false)
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
