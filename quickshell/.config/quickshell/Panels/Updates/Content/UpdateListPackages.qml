pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Core
import qs.Primitives
import qs.Core.Services as Services


Item {
    id: root
    implicitHeight: Math.min(
        Services.UpdatesTracking.packagesToUpdate.count * 44 + 16,
        44 * 5 + 16
    )

    // ── Background: líneas divisoras ─────────────────────────
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: Appearance.md3.outline_variant
        z: 2
    }
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        color: Appearance.md3.outline_variant
        z: 2
    }

    // ── Content ──────────────────────────────────────────────
    StyledText {
        anchors.centerIn: parent
        visible: Services.UpdatesTracking.updateCount === 0
            && !Services.UpdatesTracking.checking
        text: Services.I18nService.getTranslation("update.no_pending")
        font.pixelSize: 13
        color: Appearance.md3.on_surface_variant
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

        ScrollBar.vertical: StyledScrollBar {}

        delegate: UpdatePackageDelegate {
            required property var modelData
            width: packageList.width
            packageName: modelData.name
            oldVersion: modelData.oldVersion
            newVersion: modelData.newVersion
        }
    }
}
