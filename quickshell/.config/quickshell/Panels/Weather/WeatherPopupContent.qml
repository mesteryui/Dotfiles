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
import qs.Core.Modules

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
        // Reemplaza el bloque dentro de RowLayout (el icono y ColumnLayout) por este:

        RowLayout {
            id: currentRow
            Layout.fillWidth: true
            spacing: 12
            Layout.alignment: Qt.AlignVCenter

            // Icono con tamaño fijo para que no cambie con el texto
            Item {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56

                Layout.alignment: Qt.AlignVCenter

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: Icons.getWeatherIcon(WeatherService.data.wCode)
                    font.pixelSize: 46
                    color: Appearance.md3.primary
                }
            }

            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    StyledText {
                        text: WeatherService.data.temp
                        color: Appearance.md3.on_surface
                        font.pixelSize: 28
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: I18nService.getTranslation("weather.feels_like", "Sensación %1").arg(WeatherService.data.tempFeelsLike)
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
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
                    text: I18nService.getTranslation("weather.humidity_wind", "Humedad %1 · Viento %2").arg(WeatherService.data.humidity).arg(WeatherService.data.wind)
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
        // --- Previsión próximos días (reemplazar el RowLayout forecastRow existente) ---
        RowLayout {
            id: forecastRow
            visible: WeatherService.data.forecast.length > 0
            Layout.fillWidth: true
            spacing: 10                       // disminuido para compactar sin perder separación
            Layout.alignment: Qt.AlignHCenter

            Repeater {
                model: WeatherService.data.forecast

                delegate: ColumnLayout {
                    required property var modelData
                    Layout.preferredWidth: 68     // celdas uniformes, mejor alineación
                    Layout.minimumWidth: 56
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    StyledText {
                        text: modelData.dayLabel
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        elide: Text.ElideRight
                    }

                    MaterialIcon {
                        text: Icons.getWeatherIcon(modelData.wCode)
                        size: Appearance.font.pixelSize.huge
                        color: Appearance.md3.primary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        spacing: 6
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
