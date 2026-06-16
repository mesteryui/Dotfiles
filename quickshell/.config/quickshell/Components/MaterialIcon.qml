import QtQuick

Text {
    id: root
    property alias icon: root.iconName
    property string iconName: "settings" // The name of your icon
    property int size: 24
    property int fill: 0
    property int grade: 0
    property int opticalSize: 24

    text: root.iconName
    font.family: "Material Symbols Rounded" // or "Material Icons"
    font.pixelSize: root.size
    
    // Optional: Configure variable axes (for Material Symbols)
    font.variableAxes: ({
        "FILL": root.fill,
        "GRAD": root.grade,
        "opsz": root.opticalSize
    })
}
