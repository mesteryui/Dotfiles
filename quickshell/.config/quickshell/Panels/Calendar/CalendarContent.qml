// CalendarContent — Content
// UI del calendario: navegación, cabecera de días y grid.
// No tiene fondo propio — eso es responsabilidad de CalendarPopupWindow.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Primitives
import qs.Core
import qs.Core.Services as Services

Item {
    id: root

    // ── API con el Wrapper ────────────────────────────────────
    required property int currentMonth
    required property int currentYear
    required property int selectedDay
    required property var currentLocale

    signal prevMonthRequested()
    signal nextMonthRequested()
    signal daySelected(int day)

    // ── UI ────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── Navegación: anterior / mes+año / siguiente ────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4

            // Botón anterior — Wrapper + Background + Content
            Item {
                implicitWidth: 40; implicitHeight: 40

                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: Appearance.md3.on_surface_variant
                    opacity: prevTap.pressed ? 0.12 : prevHover.hovered ? 0.08 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "chevron_backward"
                    font.pixelSize: 22
                    color: Appearance.md3.on_surface_variant
                }

                HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                TapHandler  { id: prevTap;   onTapped: root.prevMonthRequested() }
            }

            // Título mes + año
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.currentLocale.standaloneMonthName(root.currentMonth)
                      + " " + root.currentYear
                font.variableAxes: Appearance.font.variableAxes.title
                font.pixelSize: 16
                color: Appearance.md3.on_surface
            }

            // Botón siguiente — Wrapper + Background + Content
            Item {
                implicitWidth: 40; 
                implicitHeight: 40

                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: Appearance.md3.on_surface_variant
                    opacity: nextTap.pressed ? 0.12 : nextHover.hovered ? 0.08 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "chevron_forward"
                    font.pixelSize: 22
                    color: Appearance.md3.on_surface_variant
                }

                HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                TapHandler  { id: nextTap;   onTapped: root.nextMonthRequested() }
            }
        }

        // ── Cabecera de días de la semana ─────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: {
                    const first = root.currentLocale.firstDayOfWeek
                    const days = []
                    for (let i = 0; i < 7; i++)
                        days.push(root.currentLocale.standaloneDayName(
                            (first + i) % 7, Locale.ShortFormat))
                    return days
                }

                delegate: StyledText {
                    required property var modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.bold: true
                    font.pixelSize: 11
                    color: Appearance.md3.on_surface_variant
                }
            }
        }

        // Divisor
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Appearance.md3.outline_variant
            opacity: 0.5
        }

        // ── Grid del calendario ───────────────────────────────
        MonthGrid {
            id: monthGrid
            month: root.currentMonth
            year:  root.currentYear
            locale: root.currentLocale
            Layout.fillWidth: true
            Layout.fillHeight: true
            

            delegate: Item {
                id: delegateItem
                required property var model

                width:  monthGrid.width / 7
                height: (monthGrid.height - 10) / 6

                readonly property bool isToday: {
                    const today = new Date()
                    return model.day   === today.getDate()
                        && monthGrid.month === today.getMonth()
                        && monthGrid.year  === today.getFullYear()
                }
                readonly property bool isCurrentMonth: model.month === monthGrid.month
                readonly property bool isSelected: root.selectedDay === model.day
                                                && isCurrentMonth

                // ── Background: círculo M3 con 3 estados ──────
                // Hoy → primary lleno
                // Seleccionado → primary_container + borde
                // Normal → transparente
                Rectangle {
                    id: dayCircle
                    width: 36; height: 36
                    radius: 18
                    anchors.centerIn: parent

                    color: delegateItem.isToday    ? Appearance.md3.primary
                         : delegateItem.isSelected ? Appearance.md3.primary_container
                         : "transparent"

                    border.width: delegateItem.isSelected && !delegateItem.isToday ? 1 : 0
                    border.color: Appearance.md3.primary

                    Behavior on color {
                        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // State layer — hover 8%, press 12%
                    Rectangle {
                        id: dayStateLayer
                        anchors.fill: parent
                        radius: parent.radius
                        color: delegateItem.isToday    ? Appearance.md3.on_primary
                             : delegateItem.isSelected ? Appearance.md3.on_primary_container
                             : Appearance.md3.on_surface
                        opacity: 0
                        Behavior on opacity {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    // ── Content: número del día ────────────────
                    StyledText {
                        anchors.centerIn: parent
                        text: delegateItem.model.day
                        font.family: Services.ConfigService.configs.appearence.fontSans
                        font.pixelSize: 13
                        font.bold: delegateItem.isToday || delegateItem.isSelected
                        color: delegateItem.isToday    ? Appearance.md3.on_primary
                             : delegateItem.isSelected ? Appearance.md3.on_primary_container
                             : delegateItem.isCurrentMonth ? Appearance.md3.on_surface
                             : Appearance.md3.on_surface_variant
                        opacity: delegateItem.isCurrentMonth ? 1.0 : 0.38
                    }
                }

                // Interacción — accede a dayStateLayer por id (mismo scope)
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: delegateItem.isCurrentMonth
                    cursorShape: delegateItem.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onContainsMouseChanged: dayStateLayer.opacity = containsMouse ? 0.08 : 0.0
                    onPressed:  dayStateLayer.opacity = 0.12
                    onReleased: dayStateLayer.opacity = containsMouse ? 0.08 : 0.0
                    onClicked:  root.daySelected(delegateItem.model.day)
                }
            }
        }
    }
}
