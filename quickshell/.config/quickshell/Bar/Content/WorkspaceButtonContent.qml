import QtQuick
import qs.Core.Services as Services
Text {
    property string workspaceButton
    font.family: Services.ConfigService.configs.appearence.fontSans
    anchors.centerIn: parent
    text: workspaceButton
}