// ControlsTabBar — pestañas Sistema/Clima (segmented buttons M3).
// Extraído de PanelWithControlsContent.qml. `host` es la raíz del contenido.
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property var host
    property Item focusAbove

    function focusPill(index) {
        const pill = tabRepeater.itemAt(index);
        if (pill)
            pill.forceActiveFocus();
    }

    spacing: Appearance.spacing.s

    Repeater {
        id: tabRepeater
        model: host.tabModel

        delegate: Rectangle {
            id: pill

            required property var modelData
            required property int index

            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Appearance.shape.full
            color: host.currentTab === index ? Appearance.md3.primary_container : Appearance.md3.surface_container_high
            border.width: (activeFocus && host.keyboardMode) ? 2 : 0
            border.color: Appearance.md3.primary
            activeFocusOnTab: true

            Accessible.role: Accessible.PageTab
            Accessible.name: modelData.label

            Keys.onPressed: host.keyboardMode = true
            Keys.onReturnPressed: host.currentTab = index
            Keys.onEnterPressed: host.currentTab = index
            Keys.onSpacePressed: host.currentTab = index
            Keys.onUpPressed: (focusAbove ? focusAbove.forceActiveFocus() : undefined)
            Keys.onDownPressed: host.scrollBy(host.activeFlick.height * 0.8)
            Keys.onLeftPressed: {
                if (index > 0) {
                    host.currentTab = index - 1;
                    host.focusTab(index - 1);
                }
            }
            Keys.onRightPressed: {
                if (index < host.tabModel.length - 1) {
                    host.currentTab = index + 1;
                    host.focusTab(index + 1);
                }
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    host.ensureVisible(pill);
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    icon: modelData.icon
                    size: Appearance.typeScale.bodyLarge
                    color: host.currentTab === index ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                }

                StyledText {
                    text: modelData.label
                    font.pixelSize: Appearance.typeScale.titleSmall
                    font.weight: Font.Medium
                    color: host.currentTab === index ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: host.keyboardMode = false
                onPressed: {
                    pill.forceActiveFocus();
                    host.keyboardMode = false;
                }
                onClicked: host.currentTab = index
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.motion.short3
                }
            }
        }
    }
}
