import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts

// Contenido del footer: botón primario de actualización.
// Sin fondo propio — eso es responsabilidad de UpdateListFooter.
Item {
    id: root

    signal updateRequested

    readonly property bool btnEnabled: !Services.UpdatesTracking.updating && !Services.UpdatesTracking.checking && Services.UpdatesTracking.updateCount > 0

    // Botón — Wrapper
    Item {
        anchors.centerIn: parent
        width: parent.width - 32
        height: 38

        // Background
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: root.btnEnabled ? Appearance.md3.primary : Qt.alpha(Appearance.md3.on_surface, 0.12)

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            // State layer
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Appearance.md3.on_primary
                opacity: btnHover.hovered && root.btnEnabled ? 0.08 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }

        // Content
        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            MaterialIcon {
                id: btnIcon

                icon: Services.UpdatesTracking.updating ? "downloading" : "system_update_alt"
                size: 12
                color: root.btnEnabled ? Appearance.md3.on_primary : Qt.alpha(Appearance.md3.on_surface, 0.38)

                RotationAnimation on rotation {
                    running: Services.UpdatesTracking.updating
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    onRunningChanged: if (!running)
                        btnIcon.rotation = 0
                }
            }

            Text {
                text: Services.UpdatesTracking.updating ? Services.I18nService.getTranslation("update.updating") : Services.UpdatesTracking.checking ? Services.I18nService.getTranslation("update.checking") : Services.I18nService.getTranslation("update.update_all")
                font.pixelSize: 13
                font.weight: Font.Medium
                font.family: Services.ConfigService.configs.appearence.fontSans
                color: root.btnEnabled ? Appearance.md3.on_primary : Qt.alpha(Appearance.md3.on_surface, 0.38)
            }
        }

        HoverHandler {
            id: btnHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: root.btnEnabled
            onTapped: {
                Services.UpdatesTracking.update();
                root.updateRequested();
            }
        }
    }
}
