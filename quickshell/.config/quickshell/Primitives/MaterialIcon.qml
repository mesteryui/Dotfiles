import QtQuick

StyledText {
    id: root
    property alias icon: root.iconName
    property string iconName: "settings" // The name of your icon
    property int size: 24
    property int fill: 0
    property int grade: 0
    property int opticalSize: 24
    // Se trunca el valor para reducir picos de consumo de memoria por re-mapeo de fuente
    property real truncatedFill: fill.toFixed(1) 

    text: root.iconName
    font {
        hintingPreference: Font.PreferNoHinting
        family: "Material Symbols Rounded"
        pixelSize: size
        weight: Font.Normal + (Font.DemiBold - Font.Normal) * truncatedFill
        variableAxes: { 
            "FILL": truncatedFill,
            // "wght": font.weight,
            // "GRAD": 0,
            "opsz": opticalSize,
        }
    }
}
