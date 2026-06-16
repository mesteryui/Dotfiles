import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
    implicitHeight: 380
    anchor.margins.top: 40
    anchor.margins.bottom: 40
    property date currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()
    grabFocus: true

    // Locale reactivo al idioma del servicio
    readonly property var currentLocale: Services.I18nService.locale

    HyprlandFocusGrab {
        windows: [calendarPopup]
        active: calendarPopup.visible
        onCleared: {
            if (calendarPopup.visible) {
                Qt.callLater(() => calendarPopup.visible = false)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Colors.surface
        border.color: Colors.outline
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Cabecera con navegación
            RowLayout {
                Layout.fillWidth: true

                Button {
                    text: "◀"
                    flat: true
                    onClicked: {
                        if (currentMonth === 0) {
                            currentMonth = 11
                            currentYear--
                        } else {
                            currentMonth--
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                    // Reactivo: se actualiza al cambiar idioma o mes
                    text: calendarPopup.currentLocale.standaloneMonthName(currentMonth) + " " + currentYear
                    font.bold: true
                    font.pixelSize: 16
                    color: Colors.on_surface
                }

                Button {
                    text: "▶"
                    flat: true
                    onClicked: {
                        if (currentMonth === 11) {
                            currentMonth = 0
                            currentYear++
                        } else {
                            currentMonth++
                        }
                    }
                }
            }

            // Días de la semana generados dinámicamente según el locale
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: {
                        const loc = calendarPopup.currentLocale
                        const first = loc.firstDayOfWeek
                        const days = []
                        for (let i = 0; i < 7; i++) {
                            const day = (first + i) % 7
                            days.push(loc.standaloneDayName(day, Locale.ShortFormat))
                        }
                        return days
                    }

                    Text {
                        Layout.fillWidth: true
                        font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.bold: true
                        font.pixelSize: 12
                        color: Colors.on_surface_variant
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.outline_variant
            }

            // Grid del calendario
            MonthGrid {
                id: monthGrid
                month: currentMonth
                year: currentYear
                locale: calendarPopup.currentLocale
                Layout.fillWidth: true
                Layout.fillHeight: true

                delegate: Rectangle {
                    required property var model

                    width: monthGrid.width / 7
                    height: (monthGrid.height - 10) / 6
                    radius: 30

                    readonly property bool isToday: {
                        const today = new Date()
                        return model.day === today.getDate()
                            && monthGrid.month === today.getMonth()
                            && monthGrid.year === today.getFullYear()
                    }
                    readonly property bool isCurrentMonth: model.month === monthGrid.month

                    color: isToday ? Colors.primary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                        text: model.day
                        font.pixelSize: 13
                        color: parent.isToday ? Colors.on_primary
                             : parent.isCurrentMonth ? Colors.on_surface
                             : Colors.on_surface_variant
                        opacity: parent.isCurrentMonth ? 1 : 0.4
                    }
                }
            }
        }
    }
}