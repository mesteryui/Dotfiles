import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Core
import qs.Primitives
import qs.Core.Services as Services

Item {
    id: root
    required property var notification
    property real progress: 1.0

    implicitWidth: 340
    implicitHeight: cardRect.height + 10 // Margen para sombra/espaciado

    // MultiEffect para sombra tonal
    MultiEffect {
        source: cardRect
        anchors.fill: cardRect
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow ?? "#000000"
        shadowOpacity: 0.12
        shadowBlur: 0.4
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
        z: -1
    }

    Rectangle {
        id: cardRect
        width: parent.width
        height: contentLayout.implicitHeight + 24
        radius: 16
        color: Appearance.md3.surface_container_high
        border.width: 1
        border.color: Appearance.md3.outline_variant

        // Área para pausar el temporizador al pasar el cursor
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            // Pausa/reanuda la animación explícitamente — no via binding,
            // para evitar que running:true la reinicie al terminar.
            onEntered: progressAnim.pause()
            onExited:  progressAnim.resume()
            onClicked: {
                // Click en la notificación puede activar la primera acción
                if (root.notification.actions.length > 0) {
                    root.notification.invokeAction(root.notification.actions[0].id);
                }
                root.notification.dismiss();
            }
        }

        ColumnLayout {
            id: contentLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 12
            }
            spacing: 8

            // Fila Superior: Icono de la App, Nombre y Botón de Cerrar
            RowLayout {
                spacing: 6
                Layout.fillWidth: true

                IconImage {
                    id: appIcon
                    source: {
        const icon = root.notification.appIcon
        if (!icon || icon === "")        return "image://icon/dialog-information"
        if (icon.startsWith("/"))        return "file://" + icon
        if (icon.startsWith("http"))     return icon
        return "image://icon/" + icon   // "vesktop" → "image://icon/vesktop"
    }
                    width: 16
                    height: 16
                }

                Text {
                    text: root.notification.appName !== "" ? root.notification.appName : "Sistema"
                    font.family: Services.ConfigService.configs.appearence.fontSans
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Appearance.md3.on_surface_variant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                ButtonIcon {
                    iconName: "close"
                    iconSize: 12
                    padding: 4
                    iconColor: Appearance.md3.on_surface_variant
                    onClicked: root.notification.dismiss()
                }
            }

            // Fila Central: Título, Cuerpo e Imagen
            RowLayout {
                spacing: 12
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true

                    Text {
                        text: root.notification.summary
                        font.family: Services.ConfigService.configs.appearence.fontSans
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Appearance.md3.on_surface
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }

                    Text {
                        text: root.notification.body
                        font.family: Services.ConfigService.configs.appearence.fontSans
                        font.pixelSize: 12
                        color: Appearance.md3.on_surface_variant
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 3
                    }
                }

                // Imagen de la notificación (si existe)
                ClippingRectangle {
                    width: 48
                    height: 48
                    radius: 8
                    visible: root.notification.image !== ""
                    Layout.alignment: Qt.AlignTop

                    Image {
                        anchors.fill: parent
                        source: root.notification.image !== ""
                            ? (root.notification.image.startsWith("/") ? "file://" + root.notification.image : root.notification.image)
                            : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }

            // Fila Inferior: Botones de Acción
            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                visible: root.notification.actions.length > 0

                Repeater {
                    model: root.notification.actions
                    delegate: Rectangle {
                        id: actionButton
                        implicitWidth: actionText.implicitWidth + 24
                        implicitHeight: 28
                        radius: 6
                        color: actionMouse.containsMouse ? Appearance.md3.primary_container : Appearance.md3.surface_container
                        border.width: 1
                        border.color: Appearance.md3.outline_variant

                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: modelData.text
                            font.family: Services.ConfigService.configs.appearence.fontSans
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Appearance.md3.on_surface
                        }

                        MouseArea {
                            id: actionMouse
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                  root.notification.invokeAction(modelData.id);
                                  root.notification.dismiss();
                              }
                        }
                    }
                }
            }
        }

        // Barra de progreso de auto-cierre
        Rectangle {
            id: progressBarBg
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            color: Appearance.md3.outline_variant
            opacity: 0.2
            radius: 2
        }

        Rectangle {
            id: progressBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            height: 3
            color: Appearance.md3.primary
            radius: 2
            width: cardRect.width * root.progress
        }
    }

    PropertyAnimation {
        id: progressAnim
        target: root
        property: "progress"
        from: 1.0
        to: 0.0
        duration: {
            const timeout = root.notification.expireTimeout;
            return (timeout > 0 ? timeout : Services.ConfigService.configs.notifications.timeout) * 1000;
        }
        // Sin running:true como binding — si estuviera, el binding lo
        // reiniciaría inmediatamente al terminar antes de que expire() se ejecute.
        onFinished: Qt.callLater(() => root.notification.expire())
    }

    Component.onCompleted: progressAnim.start()
}
