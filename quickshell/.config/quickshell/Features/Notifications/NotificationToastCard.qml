pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Core
import qs.Core.Services
import qs.Primitives

// --- NotificationToastCard ---
// Tarjeta individual de un toast de notificación. Antes vivía como delegate
// inline dentro del Repeater de NotificationPopup; se separa aquí para poder
// reutilizarla (p.ej. en el centro de notificaciones) y mantener el archivo
// del PanelWindow más limpio.
Item {
    id: root

    required property var notification

    Layout.fillWidth: true
    implicitHeight: card.implicitHeight

    readonly property bool isCritical: root.notification.urgency === NotificationUrgency.Critical
    readonly property bool hasActions: root.notification.actions.length > 0
    readonly property bool hasInlineReply: root.notification.hasInlineReply

    // Sombra difusa de elevación en vez de un borde duro — toast
    // plano y suave al estilo GNOME sobre una superficie tonal MD3
    MultiEffect {
        source: card
        anchors.fill: card
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowOpacity: 0.22
        shadowBlur: 0.8
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
    }

    Rectangle {
        id: card

        width: root.width
        implicitHeight: popupContent.implicitHeight + 20
        radius: Appearance.shape.normal
        color: Appearance.md3.surface

        Behavior on implicitHeight {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Timer {
            running: true
            // Fallback a 5s si la config aún no ha cargado el timeout
            // (evita interval NaN, que nunca dispara y deja el toast fijo)
            interval: (ConfigService.configs.notifications.timeout || 5) * 1000
            onTriggered: root.notification.expire()
        }

        // Acento fino de urgencia en lugar de un borde completo —
        // indicador tipo "container" MD3, discreto como GNOME
        Rectangle {
            visible: root.isCritical
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 6
            width: 3
            radius: Appearance.shape.full
            color: Appearance.md3.error
        }

        ColumnLayout {
            id: popupContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            anchors.leftMargin: root.isCritical ? 18 : 12
            anchors.rightMargin: 28
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Icono de la app — SIEMPRE via AppIcon (usa Notification.appIcon,
                // que ya resuelve el icono de la app o el de su desktop entry)
                Item {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: 36
                    Layout.alignment: Qt.AlignTop
                    visible: popupIcon.source.toString() !== ""

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.shape.full
                        color: Appearance.md3.surface_variant
                    }

                    AppIcon {
                        id: popupIcon
                        anchors.fill: parent
                        anchors.margins: 4
                        source: {
                            const img = root.notification.image;
                            if (img && img !== "")
                                return img;
                            const appIcon = root.notification.appIcon;
                            if (!appIcon || appIcon === "")
                                return "";
                            return Quickshell.iconPath(appIcon, true);
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.notification.summary
                        visible: text !== ""
                        color: Appearance.md3.on_surface
                        font.family: Appearance.font.sans
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.notification.body
                        visible: text !== ""
                        color: Appearance.md3.on_surface_variant
                        font.family: Appearance.font.sans
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Botones de acción — forma de píldora, MD3 filled-tonal.
            // Fila con scroll horizontal en vez de Flow: con muchas
            // acciones un Flow puede envolver a una segunda línea y hacer
            // crecer la tarjeta de forma impredecible. Así el alto queda
            // fijo y predecible.
            Item {
                Layout.fillWidth: true
                implicitHeight: actionRow.implicitHeight
                visible: root.hasActions
                clip: true

                Flickable {
                    id: actionsFlickable
                    anchors.fill: parent
                    contentWidth: actionRow.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    RowLayout {
                        id: actionRow
                        spacing: 6

                        Repeater {
                            model: root.notification.actions

                            delegate: Rectangle {
                                id: actionChip
                                required property var modelData

                                width: actionLabel.implicitWidth + 20
                                height: actionLabel.implicitHeight + 10
                                radius: Appearance.shape.full
                                color: actionArea.pressed ? Appearance.md3.primary : Appearance.md3.primary_container
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }

                                StyledText {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: actionChip.modelData.text
                                    color: actionArea.pressed ? Appearance.md3.on_primary : Appearance.md3.primary
                                    font.family: Appearance.font.sans
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }

                                MouseArea {
                                    id: actionArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: actionChip.modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }

            // Respuesta en línea — sólo si el servidor y la notificación la
            // soportan (Notification.hasInlineReply). Envía con Enter o con
            // el botón de "send".
            RowLayout {
                Layout.fillWidth: true
                visible: root.hasInlineReply
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Appearance.shape.full
                    color: Appearance.md3.surface_variant
                    border.width: replyInput.activeFocus ? 2 : 0
                    border.color: Appearance.md3.primary
                    Behavior on border.width {
                        NumberAnimation {
                            duration: 100
                        }
                    }

                    TextInput {
                        id: replyInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Appearance.md3.on_surface
                        font.family: Appearance.font.sans
                        font.pixelSize: Appearance.font.pixelSize.smaller

                        function submit() {
                            if (text.trim() === "")
                                return;
                            root.notification.sendInlineReply(text);
                            text = "";
                        }
                        onAccepted: submit()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: replyInput.text === "" && !replyInput.activeFocus
                            text: root.notification.inlineReplyPlaceholder !== "" ? root.notification.inlineReplyPlaceholder : I18nService.getTranslation("notifications.reply", "Responder…")
                            color: Appearance.md3.on_surface_variant
                            font.family: Appearance.font.sans
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: Appearance.shape.full
                    color: sendArea.pressed ? Appearance.md3.primary : Appearance.md3.primary_container
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }

                    MaterialIcon {
                        icon: "send"
                        anchors.centerIn: parent
                        color: sendArea.pressed ? Appearance.md3.on_primary : Appearance.md3.primary
                    }

                    MouseArea {
                        id: sendArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: replyInput.submit()
                    }
                }
            }
        }

        // Botón (×) para cerrar la notificación — botón circular tonal
        Item {
            width: 24
            height: 24
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8

            Rectangle {
                id: closeStateLayer
                anchors.fill: parent
                radius: Appearance.shape.full
                color: Appearance.md3.on_surface
                opacity: 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }

            MaterialIcon {
                icon: "close"
                anchors.centerIn: parent
                color: Appearance.md3.on_surface_variant
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: closeStateLayer.opacity = 0.10
                onExited: closeStateLayer.opacity = 0
                onPressed: closeStateLayer.opacity = 0.16
                onReleased: closeStateLayer.opacity = containsMouse ? 0.10 : 0
                onClicked: root.notification.dismiss()
            }
        }
    }
}