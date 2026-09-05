pragma ComponentBehavior: Bound

import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Layouts

/**
 * CheatsheetKeybindRow
 * ---------------------
 * One row inside a CheatsheetCategoryCard:
 *   [Super] + [Shift] + [Q]   Close active window
 *
 * `bind` is one entry from CheatsheetKeybinds.groupedKeybinds[category]:
 *   { mods: string[], keyLabel: string, label: string, repeat: bool, searchText: string }
 */
Item {
    id: root

    required property var bind
    /// Set to true by the parent when this row is the keyboard-focused item.
    property bool highlighted: false

    /// Emitted when the mouse starts hovering this row (not on exit, so
    /// moving the mouse off the cheatsheet doesn't clear the selection).
    signal hoverEntered

    implicitWidth: 320
    implicitHeight: content.implicitHeight + 16

    // Keyboard-focus highlight layer — primary tint, always below the hover layer.
    Rectangle {
        id: focusLayer

        anchors.fill: parent
        radius: Appearance.shape.small
        color: Appearance.md3.primary
        opacity: root.highlighted ? 0.15 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    // State layer — hover only, this row has no click action of its own
    // but visually confirms which shortcut the user is scanning.
    Rectangle {
        id: stateLayer

        anchors.fill: parent
        radius: Appearance.shape.small   // usa token en lugar de número hardcodeado
        color: Appearance.md3.on_surface
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
    }

    HoverHandler {
        onHoveredChanged: {
            stateLayer.opacity = hovered ? 0.08 : 0;
            if (hovered)
                root.hoverEntered();
        }
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 8
            rightMargin: 8
        }

        spacing: 6

        Row {
            id: keyRow

            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            Repeater {
                model: root.bind.mods
                delegate: Row {
                    required property string modelData

                    spacing: 4

                    CheatsheetKeyChip {
                        label: modelData
                    }
                    // "+" separador usando StyledText de Primitives
                    StyledText {
                        text: "+"
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            CheatsheetKeyChip {
                label: root.bind.keyLabel
            }
        }

        // Descripción de la acción usando StyledText de Primitives
        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.bind.label
            color: Appearance.md3.on_surface_variant
            font.pixelSize: Appearance.font.pixelSize.smallie
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignRight
        }
    }
}
