import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick

Item {
    id: root

    property int count: Services.NotificationService.history ? Services.NotificationService.history.count : 0
    property bool dnd: Services.NotificationService.dnd

    implicitWidth: iconItem.width
    implicitHeight: 30

    MaterialIcon {
        id: iconItem

        anchors.verticalCenter: parent.verticalCenter
        size: Appearance.font.pixelSize.larger
        fill: root.count > 0 ? 1 : 0
        color: root.dnd ? Appearance.md3.on_surface_variant : Appearance.md3.on_surface
        icon: {
            if (root.dnd)
                return "do_not_disturb_on";
            if (root.count > 0)
                return "notifications_active";
            return "notifications";
        }
    }

    Rectangle {
        id: badge

        visible: root.count > 0
        anchors.left: iconItem.right
        anchors.leftMargin: -10
        anchors.top: iconItem.top
        anchors.topMargin: -2
        implicitWidth: Math.max(16, badgeText.implicitWidth + 8)
        implicitHeight: 16
        radius: Appearance.shape.full
        color: Appearance.md3.primary
        border.width: 2
        border.color: Appearance.md3.surface_container_high

        StyledText {
            id: badgeText

            anchors.centerIn: parent
            text: root.count > 99 ? "99+" : root.count
            color: Appearance.md3.on_primary
            font.pixelSize: 9
            font.bold: true
        }
    }
}
