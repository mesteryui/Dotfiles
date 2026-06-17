import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Hyprland
import Quickshell
import Quickshell.Widgets
import "../../Core"
import "../../Core/Services" as Services

PopupWindow {
    id: calendarPopup
    color: "transparent"
    visible: false
    implicitWidth: 320
    implicitHeight: 400
    grabFocus: true

    property date currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()
    property int selectedDay: -1   // M3: día con selección explícita

    readonly property var currentLocale: Services.I18nService.locale

    HyprlandFocusGrab {
        windows: [calendarPopup]
        active: calendarPopup.visible
        onCleared: {
            if (calendarPopup.visible)
                Qt.callLater(() => calendarPopup.visible = false)
        }
    }

    // ── Contenedor principal ─────────────────────────────────────────
    // M3 Date Picker Dialog: radius 28dp, surface_container_high, elevation 3
    Rectangle {
        anchors.fill: parent
        radius: 28
        color: Colors.md3.surface
        border.color: Colors.md3.outline_variant
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colors.md3.shadow
            shadowBlur: 0.85
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
            blurMax: 32
            shadowOpacity: 0.18
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            // ── Cabecera: Icon Buttons + mes/año ─────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                // M3 Icon Button — anterior
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: "transparent"

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (currentMonth === 0) { currentMonth = 11; currentYear-- }
                            else { currentMonth-- }
                            calendarPopup.selectedDay = -1
                        }
                    }

                    // State layer: hover 8 %, press 12 %
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius
                        color: Colors.md3.on_surface_variant
                        opacity: prevArea.pressed ? 0.12 : prevArea.containsMouse ? 0.08 : 0.0
                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        font.pixelSize: 22
                        color: Colors.md3.on_surface_variant
                    }
                }

                // Título: monthName + año — titleMedium M3
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                    text: calendarPopup.currentLocale.standaloneMonthName(currentMonth)
                          + " " + currentYear
                    font.bold: true
                    font.pixelSize: 16
                    color: Colors.md3.on_surface
                }

                // M3 Icon Button — siguiente
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: "transparent"

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (currentMonth === 11) { currentMonth = 0; currentYear++ }
                            else { currentMonth++ }
                            calendarPopup.selectedDay = -1
                        }
                    }

                    Rectangle {
                        anchors.fill: parent; radius: parent.radius
                        color: Colors.md3.on_surface_variant
                        opacity: nextArea.pressed ? 0.12 : nextArea.containsMouse ? 0.08 : 0.0
                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        font.pixelSize: 22
                        color: Colors.md3.on_surface_variant
                    }
                }
            }

            // ── Días de la semana — labelMedium M3 ───────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: {
                        const loc = calendarPopup.currentLocale
                        const first = loc.firstDayOfWeek
                        const days = []
                        for (let i = 0; i < 7; i++)
                            days.push(loc.standaloneDayName((first + i) % 7, Locale.ShortFormat))
                        return days
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                        text: modelData
                        font.bold: true
                        font.pixelSize: 11
                        color: Colors.md3.on_surface_variant
                    }
                }
            }

            // Divisor sutil
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.md3.outline_variant
                opacity: 0.5
            }

            // ── Grid del calendario ───────────────────────────────────
            MonthGrid {
                id: monthGrid
                month: currentMonth
                year: currentYear
                locale: calendarPopup.currentLocale
                Layout.fillWidth: true
                Layout.fillHeight: true

                delegate: Item {
                    required property var model

                    width: monthGrid.width / 7
                    height: (monthGrid.height - 10) / 6

                    readonly property bool isToday: {
                        const today = new Date()
                        return model.day === today.getDate()
                            && monthGrid.month === today.getMonth()
                            && monthGrid.year === today.getFullYear()
                    }
                    readonly property bool isCurrentMonth: model.month === monthGrid.month
                    readonly property bool isSelected: calendarPopup.selectedDay === model.day
                                                       && isCurrentMonth

                    // ── Círculo M3 con 3 estados ─────────────────────
                    // Hoy → filled primary
                    // Seleccionado → primary_container + borde primary
                    // Normal → transparente
                    Rectangle {
                        id: dayCircle
                        width: 36; height: 36
                        radius: 18
                        anchors.centerIn: parent

                        color: isToday    ? Colors.md3.primary
                             : isSelected ? Colors.md3.primary_container
                             : "transparent"

                        border.width: isSelected && !isToday ? 1 : 0
                        border.color: Colors.md3.primary

                        Behavior on color {
                            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        // State layer (hover/press) — encima del fondo, debajo del texto
                        Rectangle {
                            id: dayStateLayer
                            anchors.fill: parent; radius: parent.radius
                            color: isToday    ? Colors.md3.on_primary
                                 : isSelected ? Colors.md3.on_primary_container
                                 : Colors.md3.on_surface
                            opacity: 0
                            Behavior on opacity {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }

                        // Número del día — bodyMedium / labelLarge M3
                        Text {
                            anchors.centerIn: parent
                            font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                            text: model.day
                            font.pixelSize: 13
                            font.bold: isToday || isSelected
                            color: isToday    ? Colors.md3.on_primary
                                 : isSelected ? Colors.md3.on_primary_container
                                 : isCurrentMonth ? Colors.md3.on_surface
                                 : Colors.md3.on_surface_variant
                            // M3 disabled state = 38 % opacidad
                            opacity: isCurrentMonth ? 1.0 : 0.38
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: isCurrentMonth
                        cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onContainsMouseChanged:
                            dayStateLayer.opacity = containsMouse ? 0.08 : 0.0
                        onPressed:
                            dayStateLayer.opacity = 0.12
                        onReleased:
                            dayStateLayer.opacity = containsMouse ? 0.08 : 0.0
                        onClicked:
                            calendarPopup.selectedDay = model.day
                    }
                }
            }
        }
    }
}