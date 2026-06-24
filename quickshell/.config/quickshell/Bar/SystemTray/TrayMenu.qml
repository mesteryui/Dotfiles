pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Primitives
import qs.Core

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

                delegate: Loader {
                    id: menuLoader
                    required property QsMenuEntry modelData
                    width: menuColumn.width

                    // Carga separador o item normal según el tipo
                    sourceComponent: modelData.isSeparator
                        ? separatorComponent
                        : menuItemComponent

                    Component {
                        id: separatorComponent
                        Rectangle {
                            width: parent?.width ?? 0
                            height: 1
                            color: Appearance.md3.outline_variant
                            opacity: 0.5
                        }
                    }

                    Component {
                        id: menuItemComponent
                        Rectangle {
                            id: itemRoot
                            width: parent?.width ?? 0
                            implicitHeight: 36
                            radius: 8
                            color: itemMouse.containsMouse
                                ? Appearance.md3.primary
                                : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }

                            opacity: menuLoader.modelData.enabled ? 1.0 : 0.4

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                spacing: 8

                                // Icono (si tiene)
                                Image {
                                    visible: menuLoader.modelData.icon !== ""
                                    source: menuLoader.modelData.icon
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                    fillMode: Image.PreserveAspectFit
                                }
                                
                                // Texto
                                StyledText {
                                    Layout.fillWidth: true
                                    text: menuLoader.modelData.text
                                    color: itemMouse.containsMouse ? Appearance.md3.on_primary : Appearance.md3.on_surface
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Behavior on color {
                                ColorAnimation { duration: 100 }
                            }
                                }

                                // Indicador de submenú
                                MaterialIcon {
                                    visible: menuLoader.modelData.hasChildren
                                    text: "chevron_right"
                                    color: Appearance.md3.on_surface_variant
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                }

                                // Checkbox / radio
                                Rectangle {
                                    visible: menuLoader.modelData.buttonType !== QsMenuButtonType.None
                                    Layout.preferredWidth: 16; Layout.preferredHeight: 16
                                    radius: menuLoader.modelData.buttonType === QsMenuButtonType.Radio ? 8 : 4
                                    color: menuLoader.modelData.checkState === Qt.Checked
                                        ? Appearance.md3.primary
                                        : "transparent"
                                    border.color: Appearance.md3.outline
                                    border.width: 1
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: menuLoader.modelData.enabled
                                onClicked: {
                                    if (menuLoader.modelData.hasChildren) {
                                        // submenú — por ahora usa display nativo
                                        const pos = itemRoot.mapToGlobal(itemRoot.width, 0)
                                        menuLoader.modelData.display(root.QsWindow.window, pos.x, pos.y)
                                    } else {
                                        menuLoader.modelData.triggered()
                                        root.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}