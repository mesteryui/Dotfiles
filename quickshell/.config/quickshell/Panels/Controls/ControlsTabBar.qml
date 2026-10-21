// ControlsTabBar — pestañas Sistema/Clima (segmented buttons M3).
// Extraído de PanelWithControlsContent.qml. `host` es la raíz del contenido.
pragma ComponentBehavior: Bound

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

    spacing: Appearance.spacing.small

    Repeater {
        id: tabRepeater

        model: root.host.tabModel

        delegate: Rectangle {
            id: pill

            required property var modelData
            required property int index

            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Appearance.shape.full
            color: root.host.currentTab === index ? Appearance.md3.primary_container :
                                                    Appearance.md3.surface_container_high

            border.width: (activeFocus && root.host.keyboardMode) ? Appearance.border.focusWidth : 0
            border.color: Appearance.border.focus
            activeFocusOnTab: true

            Accessible.role: Accessible.PageTab
            Accessible.name: modelData.label

            Keys.onPressed: root.host.keyboardMode = true
            Keys.onReturnPressed: root.host.currentTab = index
            Keys.onEnterPressed: root.host.currentTab = index
            Keys.onSpacePressed: root.host.currentTab = index
            Keys.onUpPressed: (root.focusAbove ? root.focusAbove.forceActiveFocus() : undefined)
            Keys.onDownPressed: root.host.scrollBy(root.host.activeFlick.height * 0.8)
            Keys.onLeftPressed: {
                if (index > 0) {
                    root.host.currentTab = index - 1;
                    root.host.focusTab(index - 1);
                }
            }
            Keys.onRightPressed: {
                if (index < root.host.tabModel.length - 1) {
                    root.host.currentTab = index + 1;
                    root.host.focusTab(index + 1);
                }
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    root.host.ensureVisible(pill);
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                MaterialIcon {
                    icon: pill.modelData.icon
                    size: Appearance.typeScale.bodyLarge
                    color: root.host.currentTab === pill.index ? Appearance.md3.on_primary_container :
                                                                 Appearance.md3.on_surface_variant
                }

                StyledText {
                    text: pill.modelData.label
                    font.pixelSize: Appearance.typeScale.titleSmall
                    font.weight: Font.Medium
                    color: root.host.currentTab === pill.index ? Appearance.md3.on_primary_container :
                                                                 Appearance.md3.on_surface_variant
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.host.keyboardMode = false
                onPressed: {
                    pill.forceActiveFocus();
                    root.host.keyboardMode = false;
                }
                onClicked: root.host.currentTab = pill.index
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.motion.fast
                }
            }
        }
    }
}
