// Services/I18nService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Idioma actual. Podría detectarse automáticamente o guardarse en una config.
    property string userDefinedLang: ConfigService.getConfig("language")
    property var locale: userDefinedLang == "" ? Qt.locale() : Qt.locale(userDefinedLang)
    property string language: userDefinedLang == "" ? Qt.locale().name : userDefinedLang

    // Diccionario con las traducciones cargadas
    property var translations: ({})

    FileView {
        id: fileManagment
        path: Quickshell.shellPath("i18n/" + root.language + ".json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.translations = JSON.parse(fileManagment.text());
            } catch (e) {
                console.error("I18n error:", e);
            }
        }
    }
    function getTranslation(key: string, default_key = ""): var {
        const parts = key.split(".");
        let current = root.translations;
        for (const part of parts) {
            if (current === undefined || current === null)
                return default_key;
            current = current[part];
        }
        return current ?? default_key;
    }
}
