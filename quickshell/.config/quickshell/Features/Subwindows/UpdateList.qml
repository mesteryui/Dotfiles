import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Hyprland
import "../../Core/Services" as Services
import "../../Core"
import "../../Components"

PopupWindow {
    id: root
    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: 300
    implicitHeight: Math.min(500, header.implicitHeight + listSection.implicitHeight + footer.implicitHeight)

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible)
                Qt.callLater(() => root.visible = false);
        }
    }

    // Borde exterior
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "transparent"
        border.color: Colors.outline_variant
        border.width: 1
        z: 10
    }

    Rectangle {
        id: content
        anchors.fill: parent
        radius: 20
        color: Colors.surface
        clip: true

        // ── Cabecera ──────────────────────────────────────────
        Item {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            implicitHeight: 70

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.primary_container, 0.6)
            }

            Rectangle {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 40
                z: 2
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.tint(Colors.surface, Qt.alpha(Colors.primary, 0.08)) }
                }
            }

            Row {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    margins: 16
                    bottomMargin: 12
                }
                spacing: 10
                z: 3

                MaterialIcon {
                    id: icono
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Services.UpdatesTracking.failed   ? "warning"          :
                          Services.UpdatesTracking.checking ? "sync"             :
                                                              "system_update_alt"
                    color: Services.UpdatesTracking.failed  ? Colors.error : Colors.on_surface
                    size: 20
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: Services.UpdatesTracking.failed   ? "Error al comprobar"                              :
                              Services.UpdatesTracking.checking ? "Comprobando…"                                    :
                              Services.UpdatesTracking.updateCount === 0 ? "Al día"                                 :
                              Services.UpdatesTracking.updateCount + " paquete" +
                              (Services.UpdatesTracking.updateCount !== 1 ? "s" : "") + " disponible" +
                              (Services.UpdatesTracking.updateCount !== 1 ? "s" : "")
                        font.family: Services.ConfigService.getConfig("fontSans","sans-serif")
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Services.UpdatesTracking.failed ? Colors.error : Colors.on_surface
                    }
                }
            }

            // Botón refrescar
            ButtonIcon {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: 12
                }
                z: 3
                iconName: "refresh"
                iconSize: 18
                enabled: !Services.UpdatesTracking.checking && !Services.UpdatesTracking.updating
                onClicked: Services.UpdatesTracking.checkNow()
            }
        }

        // ── Lista de paquetes ─────────────────────────────────
        Item {
            id: listSection
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                bottom: footer.top
            }
            // Altura máxima: 5 items visibles (44px cada uno) + padding
            implicitHeight: Math.min(
                Services.UpdatesTracking.packagesToUpdate.count * 44 + 16,
                44 * 5 + 16
            )

            // Borde superior e inferior para delimitar la lista
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                color: Colors.outline_variant
                z: 2
            }
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: Colors.outline_variant
                z: 2
            }

            // Estado vacío
            Text {
                anchors.centerIn: parent
                visible: Services.UpdatesTracking.updateCount === 0 && !Services.UpdatesTracking.checking
                text: "No hay actualizaciones pendientes"
                font.pixelSize: 13
                font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                color: Colors.on_surface_variant
            }

            ListView {
                id: packageList
                anchors {
                    fill: parent
                    topMargin: 8
                    bottomMargin: 8
                }
                clip: true
                model: Services.UpdatesTracking.packagesToUpdate
                spacing: 0

                ScrollBar.vertical: ScrollBar {
                    policy: packageList.contentHeight > packageList.height
                            ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                }

                delegate: Item {
                    width: packageList.width
                    height: 44

                    // Highlight en hover
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        radius: 8
                        color: Qt.alpha(Colors.primary, delegateHover.containsMouse ? 0.08 : 0)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    HoverHandler { id: delegateHover }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 16
                        }
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: model.name
                            font.pixelSize: 13
                            font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                            color: Colors.on_surface
                            elide: Text.ElideRight
                        }

                        Text {
                            text: model.oldVersion
                            font.pixelSize: 11
                            font.family: Services.ConfigService.getConfig("fontMono") || "monospace"
                            color: Colors.on_surface_variant
                            opacity: 0.7
                        }

                        MaterialIcon {
                            icon: "arrow_forward"
                            size: 12
                            color: Colors.primary
                        }

                        Text {
                            text: model.newVersion
                            font.pixelSize: 11
                            font.family: Services.ConfigService.getConfig("fontMono","monospace")
                            color: Colors.primary
                        }
                    }
                }
            }
        }

        // ── Pie con botón ─────────────────────────────────────
        Item {
            id: footer
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            implicitHeight: 64

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colors.surface_variant, 0.3)
            }

            // Botón actualizar
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 32
                height: 38
                radius: 10
                color: {
                    if (!updateBtn.enabled)
                        return Qt.alpha(Colors.on_surface, 0.12);
                    if (updateBtn.containsMouse)
                        return Qt.tint(Colors.primary, Qt.alpha(Colors.on_primary, 0.08));
                    return Colors.primary;
                }
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        id: icon
                        icon: Services.UpdatesTracking.updating ? "downloading" : "system_update_alt"
                        size: 16
                        color: !updateBtn.enabled ? Qt.alpha(Colors.on_surface, 0.38) : Colors.on_primary

                        RotationAnimation on rotation {
                            running: Services.UpdatesTracking.updating
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) icon.rotation = 0
                        }
                    }

                    Text {
                        text: Services.UpdatesTracking.updating  ? "Actualizando…" :
                              Services.UpdatesTracking.checking   ? "Comprobando…"  :
                                                                    "Actualizar todo"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                        color: !updateBtn.enabled
                               ? Qt.alpha(Colors.on_surface, 0.38)
                               : Colors.on_primary
                    }
                }

                HoverHandler { id: updateBtn; enabled: parent.enabled; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    enabled: !Services.UpdatesTracking.updating &&
                             !Services.UpdatesTracking.checking &&
                             Services.UpdatesTracking.updateCount > 0
                    onTapped: {
                        Services.UpdatesTracking.update()
                        root.visible = false
                    }
                }

                enabled: !Services.UpdatesTracking.updating &&
                         !Services.UpdatesTracking.checking &&
                         Services.UpdatesTracking.updateCount > 0
            }
        }
    }
}
