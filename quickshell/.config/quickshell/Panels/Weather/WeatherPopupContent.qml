// --- WeatherContent ---
// Muestra el clima actual (icono, temperatura, sensación térmica, ciudad,
// mínima/máxima de hoy y rejilla de detalles) y una fila con la previsión
// de los próximos días, leyendo directamente de WeatherService.
import qs.Primitives
import qs.Core
import qs.Core.Services
import qs.Core.Modules
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    function aqiLabel(level) {
        if (level >= 6)
            return I18nService.getTranslation("weather.aqi_extremely_poor", "Pésima");
        if (level === 5)
            return I18nService.getTranslation("weather.aqi_very_poor", "Muy mala");
        if (level === 4)
            return I18nService.getTranslation("weather.aqi_poor", "Mala");
        if (level === 3)
            return I18nService.getTranslation("weather.aqi_moderate", "Moderada");
        if (level === 2)
            return I18nService.getTranslation("weather.aqi_fair", "Aceptable");
        if (level === 1)
            return I18nService.getTranslation("weather.aqi_good", "Buena");
        return "--";
    }

    implicitHeight: mainColumn.implicitHeight + mainColumn.anchors.margins * 2
    implicitWidth: Math.max(mainColumn.implicitWidth + mainColumn.anchors.margins * 2, 320)

    ColumnLayout {
        id: mainColumn

        anchors.fill: parent
        anchors.margins: Appearance.spacing.m
        spacing: 10

        // --- Clima actual ---
        RowLayout {
            id: currentRow
            Layout.fillWidth: true

            spacing: Appearance.spacing.m
            Layout.alignment: Qt.AlignVCenter

            Item {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignVCenter

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: Icons.getWeatherIcon(WeatherService.data.wCode, WeatherService.data.isDay)
                    font.pixelSize: 46
                    color: Appearance.md3.primary
                }
            }

            ColumnLayout {
                spacing: Appearance.spacing.xs
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    spacing: Appearance.spacing.s
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

                // Mínima / máxima de hoy (humedad y viento solo en la rejilla)
                StyledText {
                    text: I18nService.getTranslation("weather.max_min", "Máx %1 · Mín %2").arg(WeatherService.data.tempMax).arg(WeatherService.data.tempMin)
                    color: Appearance.md3.on_surface
                    font.pixelSize: 12
                    font.weight: Font.Medium
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

        // --- Avisos MeteoAlarm (solo si los hay) ---
        WeatherAlerts {
            Layout.fillWidth: true
        }

        // --- Detalles de hoy ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Appearance.md3.outline_variant
        }

        GridLayout {
            id: detailsGrid
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 8
            columnSpacing: 8

            // Cada celda: icono + columna(valor + etiqueta)
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "air"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: WeatherService.data.wind + " " + WeatherService.data.windDir
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.wind", "Viento")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "water_drop"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: WeatherService.data.humidity
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.humidity", "Humedad")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "compress"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: WeatherService.data.press
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.pressure", "Presión")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "visibility"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: WeatherService.data.visib
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.visibility", "Visibilidad")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "rainy"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: WeatherService.data.precip
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.precipitation", "Precipitación")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "umbrella"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: WeatherService.data.precipProb
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.precipitation_probability", "Prob. lluvia")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "light_mode"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: String(WeatherService.data.uv)
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.uv_index", "Índice UV")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "wb_twilight"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: WeatherService.data.sunrise
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.sunrise", "Amanecer")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "bedtime"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: WeatherService.data.sunset
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.sunset", "Atardecer")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.s
                MaterialIcon {
                    icon: "eco"
                    size: 20
                    color: Appearance.md3.primary
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    StyledText {
                        text: WeatherService.data.aqi >= 0 ? WeatherService.data.aqi + " · " + root.aqiLabel(WeatherService.data.aqiLevel) : "--"
                        color: Appearance.md3.on_surface
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: I18nService.getTranslation("weather.aqi_title", "Calidad del aire")
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: 10
                    }
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
            spacing: 10
            Layout.alignment: Qt.AlignHCenter

            Repeater {
                model: WeatherService.data.forecast

                delegate: ColumnLayout {
                    required property var modelData
                    Layout.preferredWidth: 68
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

                    StyledText {
                        visible: modelData.precipProb > 0
                        text: modelData.precipProb + "%"
                        color: Appearance.md3.tertiary
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
