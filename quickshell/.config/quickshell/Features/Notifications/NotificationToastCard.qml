pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

// --- NotificationToastCard ---
// Tarjeta de toast de notificación en estilo Material You (Material 3 Expressive).
// Presenta la imagen destacada a la izquierda del bloque de nombre de app y contenido,
// ocupando todo el ancho disponible y manteniendo una altura compacta y proporcionada.
Item {
    id: root

    required property var notification

    Layout.fillWidth: true
    implicitWidth: 380
    implicitHeight: card.implicitHeight

    readonly property bool isCritical: root.notification.urgency === NotificationUrgency.Critical

    readonly property bool hasActions: root.notification.actions && root.notification.actions.length > 0

    readonly property bool hasInlineReply: root.notification.hasInlineReply ?? false

    visible: !NotificationManager.dnd || isCritical

    // ── Temporizador de Expiración (se pausa al hacer hover) ──
    Timer {
        id: expireTimer

        running: !cardHover.hovered
        interval: (Services.ConfigService.configs.notifications.timeout || 5) * 1000
        onTriggered: root.notification.expire()
    }

    // ── Sombra de Elevación Material 3 ─────────────────────────
    MultiEffect {
        source: card
        anchors.fill: card
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowOpacity: root.isCritical ? 0.25 : 0.16
        shadowBlur: 0.6
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
    }

    // ── Tarjeta M3 Expressive Container ───────────────────────
    Rectangle {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: cardLayout.implicitHeight + 24
        radius: Appearance.shape.normal
        color: root.isCritical ? Appearance.md3.error_container : Appearance.md3.surface

        border.width: 1
        border.color: root.isCritical ? Appearance.md3.error : Qt.alpha(Appearance.md3.outline_variant, 0.45)

        Behavior on implicitHeight {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        HoverHandler {
            id: cardHover
        }

        ColumnLayout {
            id: cardLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 12
            }

            spacing: 8

            // ════════════════════════════════════════════════════
            // SECCIÓN PRINCIPAL: IMAGEN A LA IZQUIERDA + CONTENIDO
            // ════════════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Layout.alignment: Qt.AlignTop

                // ── Imagen / Icono Destacado (Grande a la izquierda) ──
                Item {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46
                    Layout.alignment: Qt.AlignTop

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.shape.small
                        color: root.isCritical ? Appearance.md3.error : Appearance.md3.primary_container

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "notifications"
                            size: 24
                            color: root.isCritical ? Appearance.md3.on_error : Appearance.md3.on_primary_container
                            visible: notifIcon.source.toString() === ""
                        }
                    }

                    AppIcon {
                        id: notifIcon

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

                // ── Bloque Derecho: Nombre de App + Título + Mensaje ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Layout.alignment: Qt.AlignTop

                    // Fila superior: Nombre de App + Badge Urgente + Botón Cerrar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: root.notification.appName || "Sistema"
                            color: root.isCritical ? Appearance.md3.on_error_container : Appearance.md3.on_surface_variant
                            font.family: Appearance.font.sans
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            Layout.maximumWidth: 180
                        }

                        // Insignia de Urgencia Crítica
                        Rectangle {
                            visible: root.isCritical
                            implicitHeight: 16
                            implicitWidth: critText.implicitWidth + 8
                            radius: Appearance.shape.full
                            color: Appearance.md3.error

                            StyledText {
                                id: critText

                                anchors.centerIn: parent
                                text: "Urgente"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.family: Appearance.font.sans
                                color: Appearance.md3.on_error
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Botón (×) Cerrar / Descartar
                        AnimatedIconButton {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            iconName: "close"
                            iconSize: 14
                            implicitWidth: 24
                            implicitHeight: 24
                            iconColor: root.isCritical ? Appearance.md3.on_error_container : Appearance.md3.on_surface_variant
                            baseColor: "transparent"
                            onClicked: root.notification.dismiss()
                        }
                    }

                    // Título (Summary)
                    StyledText {
                        Layout.fillWidth: true
                        text: root.notification.summary
                        visible: text !== ""
                        color: root.isCritical ? Appearance.md3.on_error_container : Appearance.md3.on_surface
                        font.family: Appearance.font.sans
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Mensaje (Body)
                    StyledText {
                        Layout.fillWidth: true
                        text: root.notification.body
                        visible: text !== ""
                        color: root.isCritical ? Qt.alpha(Appearance.md3.on_error_container, 0.90) : Appearance.md3.on_surface_variant
                        font.family: Appearance.font.sans
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }

            // ════════════════════════════════════════════════════
            // BOTONES DE ACCIÓN (MATERIAL 3 CHIPS)
            // ════════════════════════════════════════════════════
            Item {
                Layout.fillWidth: true
                implicitHeight: 28
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

                            delegate: AnimatedTextButton {
                                required property var modelData

                                text: modelData.text
                                isFilled: false

                                buttonHeight: 28
                                fontSize: 11
                                fontWeight: Font.Medium
                                paddingHorizontal: 20

                                baseColor: root.isCritical ? Appearance.md3.error : Appearance.md3.primary_container
                                textColor: root.isCritical ? Appearance.md3.on_error_container : Appearance.md3.on_primary_container
                                overlayColor: root.isCritical ? Appearance.md3.on_error_container : Appearance.md3.on_primary_container

                                border.width: root.isCritical ? 1 : 0
                                border.color: Appearance.md3.error

                                onClicked: modelData.invoke()
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════
            // RESPUESTA EN LÍNEA (MATERIAL YOU INLINE REPLY)
            // ════════════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                visible: root.hasInlineReply
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Appearance.shape.full
                    color: root.isCritical ? Qt.alpha(Appearance.md3.surface, 0.5) : Appearance.md3.surface_container_highest

                    border.width: replyInput.activeFocus ? 2 : 1
                    border.color: replyInput.activeFocus ? (root.isCritical ? Appearance.md3.error : Appearance.md3.primary) : (root.isCritical ? Qt.alpha(Appearance.md3.error, 0.4) : Qt.alpha(Appearance.md3.outline_variant, 0.5))

                    Behavior on border.width {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    TextInput {
                        id: replyInput

                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: root.isCritical ? Appearance.md3.on_error_container : Appearance.md3.on_surface
                        font.family: Appearance.font.sans
                        font.pixelSize: 12

                        function submit() {
                            if (text.trim() === "")
                                return;
                            root.notification.sendInlineReply(text);
                            text = "";
                        }
                        onAccepted: submit()

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: replyInput.text === "" && !replyInput.activeFocus
                            text: root.notification.inlineReplyPlaceholder !== "" ? root.notification.inlineReplyPlaceholder : Services.I18nService.getTranslation("notifications.reply", "Responder…")
                            color: root.isCritical ? Qt.alpha(Appearance.md3.on_error_container, 0.6) : Appearance.md3.on_surface_variant
                            font.family: Appearance.font.sans
                            font.pixelSize: 12
                        }
                    }
                }

                AnimatedIconButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    iconName: "send"
                    iconSize: 15
                    implicitWidth: 32
                    implicitHeight: 32
                    enabled: replyInput.text.trim().length > 0
                    iconColor: Appearance.md3.on_surface_variant
                    activeIconColor: root.isCritical ? Appearance.md3.on_error : Appearance.md3.on_primary
                    baseColor: "transparent"
                    accentColor: root.isCritical ? Appearance.md3.error : Appearance.md3.primary
                    isActive: enabled
                    onClicked: replyInput.submit()
                }
            }
        }
    }
}
