import qs.Primitives
import qs.Core.Services
import QtQuick

StyledText {
    property string workspaceButton
    property bool isFocused  // pásalo desde el delegate del workspace (active/focused)
    textFormat: Text.RichText

    text: obtainWorkspaceSymbol(workspaceButton, ConfigService.configs.bar.workspaceButtonType, isFocused)

    function obtainWorkspaceSymbol(number, typeSymbol, isFocused) {
        const workspace = parseInt(number);
        const index = workspace - 1;
        switch (typeSymbol) {
        case "numbers":
            return number;
        case "kanji":
            {
                const kanjis = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"];
                return kanjis[index] || number;
            }
        case "circles":
            {
                const circles = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩"];
                return circles[index] || number;
            }
        case "romanos":
            {
                const romanos = ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ"];
                return romanos[index] || number;
            }
        case "runas":
            {
                // Futhark antiguo, orden tradicional (fehu, uruz, thurisaz...)
                const runas = ["ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ", "ᚺ", "ᚾ"];
                return runas[index] || number;
            }
        default:
            return number;
        }
    }
}
