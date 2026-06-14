import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../"

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
        color: Colors.surface
        border.color: Colors.outline
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
                            color: Colors.outline_variant
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
                                ? Colors.primary
                                : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 100 }
                            }

                            opacity: modelData.enabled ? 1.0 : 0.4

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                spacing: 8

                                // Icono (si tiene)
                                Image {
                                    visible: modelData.icon !== ""
                                    source: modelData.icon
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                    fillMode: Image.PreserveAspectFit
                                }
                                
                                // Texto
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text
                                    color: itemMouse.containsMouse ? Colors.on_primary : Colors.on_surface
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Behavior on color {
                                ColorAnimation { duration: 100 }
                            }
                                }

                                // Indicador de submenú
                                Text {
                                    visible: modelData.hasChildren
                                    text: "›"
                                    color: Colors.on_surface_variant
                                    font.pixelSize: 16
                                }

                                // Checkbox / radio
                                Rectangle {
                                    visible: modelData.buttonType !== QsMenuButtonType.None
                                    width: 16; height: 16
                                    radius: modelData.buttonType === QsMenuButtonType.Radio ? 8 : 4
                                    color: modelData.checkState === Qt.Checked
                                        ? Colors.primary
                                        : "transparent"
                                    border.color: Colors.outline
                                    border.width: 1
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: modelData.enabled
                                onClicked: {
                                    if (modelData.hasChildren) {
                                        // submenú — por ahora usa display nativo
                                        const pos = itemRoot.mapToGlobal(itemRoot.width, 0)
                                        modelData.display(root.QsWindow.window, pos.x, pos.y)
                                    } else {
                                        modelData.triggered()
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