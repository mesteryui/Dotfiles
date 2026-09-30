// SettingsDropdownRow — dropdown M3 para listas largas.
// Extraído de SettingsPanelContent.qml para partir sus ~950 líneas.
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: dropRow

    property string label: ""
    property string value: ""
    property var choicesModel: []
    property string iconName: ""

    signal chosen(string value)

    property bool open: false
    property int activeIndex: 0

    onOpenChanged: {
        if (open)
            Qt.callLater(() => menuFlick.ensureVisible());
    }

    function syncIndex() {
        const i = dropRow.choicesModel.findIndex(o => o && o.value === dropRow.value);
        dropRow.activeIndex = i >= 0 ? i : 0;
    }

    onValueChanged: {
        if (!dropRow.open)
            dropRow.syncIndex();
    }
    Component.onCompleted: dropRow.syncIndex()

    Layout.fillWidth: true
    spacing: 6

    SettingsFieldLabel {
        text: dropRow.label
    }

    // Campo (outlined 56dp): valor + trailing que rota.
    Rectangle {
        id: dropField

        Layout.fillWidth: true
        implicitHeight: 56
        radius: Appearance.shape.extraSmall
        color: "transparent"
        border.width: dropRow.open || dropField.activeFocus ? 2 : 1
        border.color: dropRow.open || dropField.activeFocus ? Appearance.md3.primary : Appearance.md3.outline_variant
        activeFocusOnTab: true

        Accessible.role: Accessible.ComboBox
        Accessible.name: dropRow.label
        Accessible.description: dropRow.value

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.motion.short3
            }
        }

        Keys.onSpacePressed: dropRow.open = !dropRow.open
        Keys.onReturnPressed: {
            if (dropRow.open) {
                const o = dropRow.choicesModel[dropRow.activeIndex];
                dropRow.open = false;
                if (o)
                    dropRow.chosen(o.value);
            } else {
                dropRow.open = true;
            }
        }
        Keys.onEnterPressed: {
            if (dropRow.open) {
                const o = dropRow.choicesModel[dropRow.activeIndex];
                dropRow.open = false;
                if (o)
                    dropRow.chosen(o.value);
            } else {
                dropRow.open = true;
            }
        }
        Keys.onEscapePressed: dropRow.open = false
        Keys.onUpPressed: {
            if (!dropRow.open) {
                dropRow.open = true;
            } else if (dropRow.activeIndex > 0) {
                dropRow.activeIndex--;
            }
        }
        Keys.onDownPressed: {
            if (!dropRow.open) {
                dropRow.open = true;
            } else if (dropRow.activeIndex < dropRow.choicesModel.length - 1) {
                dropRow.activeIndex++;
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 12

            MaterialIcon {
                visible: dropRow.iconName !== ""
                Layout.alignment: Qt.AlignVCenter
                icon: dropRow.iconName
                size: 24
                color: Appearance.md3.on_surface_variant
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: {
                    const o = dropRow.choicesModel[dropRow.activeIndex];
                    return o ? o.text : "";
                }
                font.pixelSize: Appearance.typeScale.bodyLarge
                color: Appearance.md3.on_surface
                elide: Text.ElideRight
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: "arrow_drop_down"
                size: 24
                color: Appearance.md3.on_surface_variant
                rotation: dropRow.open ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Appearance.motion.short3
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: dropField.forceActiveFocus()
            onClicked: dropRow.open = !dropRow.open
        }
    }

    // Menú (contenedor tonal elevado, filas 48dp con check, scroll
    // interno a partir de ~5 opciones).
    Rectangle {
        visible: dropRow.open
        Layout.fillWidth: true
        implicitHeight: Math.min(menuCol.implicitHeight + 8, 5 * 48 + 8)
        radius: Appearance.shape.extraSmall
        color: Appearance.md3.surface_container_highest
        clip: true

        opacity: dropRow.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.motion.short2
            }
        }

        Flickable {
            id: menuFlick

            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            contentWidth: width
            contentHeight: menuCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StyledScrollBar {}

            function ensureVisible() {
                const y = dropRow.activeIndex * 48;
                if (y < contentY)
                    contentY = y;
                else if (y + 48 > contentY + height)
                    contentY = y + 48 - height;
            }

            Column {
                id: menuCol

                width: parent.width
                spacing: 0

                Repeater {
                    model: dropRow.choicesModel
                    delegate: Item {
                        id: menuRow

                        required property var modelData
                        required property int index

                        readonly property bool _hasModelData: modelData !== undefined && modelData !== null
                        readonly property bool _selected: _hasModelData && modelData.value === dropRow.value
                        readonly property bool _focused: index === dropRow.activeIndex

                        width: menuCol.width
                        implicitHeight: 48

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Appearance.shape.small
                            color: "transparent"
                        }

                        M3SelectionFill {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Appearance.shape.small
                            selected: menuRow._selected
                        }

                        M3StateLayer {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Appearance.shape.small
                            tint: menuRow._selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                            hovered: menuArea.pressed || menuArea.containsMouse || menuRow._focused
                            pressed: menuArea.pressed
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            MaterialIcon {
                                Layout.alignment: Qt.AlignVCenter
                                icon: "check"
                                size: 20
                                color: Appearance.md3.on_secondary_container
                                visible: menuRow._selected
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: menuRow._hasModelData ? (menuRow.modelData.text ?? "") : ""
                                font.pixelSize: Appearance.typeScale.bodyLarge
                                color: menuRow._selected ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: menuArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (menuRow._hasModelData) {
                                    dropRow.activeIndex = menuRow.index;
                                    dropRow.open = false;
                                    dropRow.chosen(menuRow.modelData.value);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
