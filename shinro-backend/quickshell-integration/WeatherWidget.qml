// WeatherWidget.qml
// Ejemplo de widget de clima que lee desde el backend shinro.
// Filtra mensajes con module === "weather".

import QtQuick 2.15
import QtQuick.Layouts 1.15

import "ShinroSocket.qml" as Shinro

Item {
    id: root

    width: 200
    height: 80

    Shinro.ShinroSocket {
        id: shinro
        locationMode: "auto"   // usar Geoclue para ubicación automática
        // city: "Madrid"     // solo si locationMode es "manual"
        systemInterval: 5
        weatherInterval: 600   // actualizar clima cada 10 minutos

        onSystemData: (data) => {
            // WeatherWidget no usa system, pero lo recibe igual
            console.log("weather widget ignorando system:", data);
        }

        onWeatherData: (data) => {
            cityText.text = data.city || "Desconocido";
            tempText.text = qsTr("%1°C").arg(data.temp_c.toFixed(1));
            condText.text = data.condition;
            humText.text = qsTr("Humedad: %1%").arg(data.humidity);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8

        Text { id: cityText; text: "Cargando..."; font.bold: true }
        Text { id: tempText; text: "--°C"; font.pixelSize: 20 }
        Text { id: condText; text: "--" }
        Text { id: humText; text: "Humedad: --%" }
    }
}
