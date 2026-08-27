import QtQuick
import qs.Core

StyledText {
    id: root
    property alias icon: root.iconName
    property string iconName: "settings" // The name of your icon
    property int size: Appearance?.font.pixelSize.small ?? 16
    property real fill: 0
    // Se trunca el valor para reducir picos de consumo de memoria por re-mapeo de fuente
    property real truncatedFill: fill.toFixed(1)
    renderType: Text.NativeRendering
    text: root.iconName
    font {
        hintingPreference: Font.PreferNoHinting
        family: Appearance.font.iconMaterial
        pixelSize: size
        weight: Font.Normal + (Font.DemiBold - Font.Normal) * truncatedFill
        variableAxes: {
            "FILL": truncatedFill,
            // "wght": font.weight,
            // "GRAD": 0,
            "opsz": size
        }
    }
}
