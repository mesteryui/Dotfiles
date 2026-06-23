import QtQuick
import qs.Core.Services as Services
import qs.Primitives
StyledText {
    property string workspaceButton
    font.family: Services.ConfigService.configs.appearence.fontSans
    text: workspaceButton
}