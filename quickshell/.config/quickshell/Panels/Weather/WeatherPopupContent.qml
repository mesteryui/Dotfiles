// --- WeatherContent ---
// Muestra el clima actual (icono, temperatura, sensación térmica, ciudad,
// humedad) y una fila con la previsión de los próximos días, leyendo
// directamente de WeatherService. Pensado para encajar en un
// Wrapper/Background exterior que le dé el fondo y el radio MD3.
import QtQuick
import QtQuick.Layouts
import qs.Primitives
import qs.Core
import qs.Core.Services

Item {
    id: root
    implicitHeight: mainColumn.implicitHeight + mainColumn.anchors.margins * 2
    implicitWidth: mainColumn.implicitWidth + mainColumn.anchors.margins * 2
    // Devuelve el nombre de ligadura de Material Symbols según el
    // weatherCode de wttr.in (WorldWeatherOnline codes).
   

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // --- Clima actual ---
        RowLayout {
            id: currentRow
            Layout.fillWidth: true
            spacing: 14

            Text {
                text: WeatherService.iconForCode(WeatherService.data.wCode)
                font.family: "Material Symbols Rounded"
                font.pixelSize: 42
                color: Appearance.md3.primary
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    spacing: 6
                    Layout.fillWidth: true

                    StyledText {
                        text: WeatherService.data.temp
                        color: Appearance.md3.on_surface
                        font.pixelSize: 26
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: qsTr("Sensación %1").arg(WeatherService.data.tempFeelsLike)
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 4
                    }
                }

                StyledText {
                    text: WeatherService.data.city
                    color: Appearance.md3.on_surface
                    font.pixelSize: 14
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledText {
                    text: qsTr("Humedad %1 · Viento %2").arg(WeatherService.data.humidity).arg(WeatherService.data.wind)
                    color: Appearance.md3.on_surface_variant
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledText {
                    visible: WeatherService.data.lastRefresh !== 0
                    text: WeatherService.data.lastRefresh
                    color: Appearance.md3.on_surface_variant
                    font.pixelSize: 10
                    Layout.fillWidth: true
                }
            }
        }

        // Separador sutil entre el clima actual y la previsión
        Rectangle {
            visible: forecastRow.visible
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Appearance.md3.outline_variant
        }

        // --- Previsión próximos días ---
        RowLayout {
            id: forecastRow
            visible: WeatherService.data.forecast.length > 0
            Layout.fillWidth: true
            spacing: 80

            Repeater {
                model: WeatherService.data.forecast

                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    StyledText {
                        text: modelData.dayLabel
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: WeatherService.iconForCode(modelData.wCode)
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: Appearance.md3.primary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignHCenter

                        StyledText {
                            text: modelData.maxTemp + "°"
                            color: Appearance.md3.on_surface
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: modelData.minTemp + "°"
                            color: Appearance.md3.on_surface_variant
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
