pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Idioma configurado. "auto" significa adaptar al idioma del sistema.
    property string userDefinedLang: ConfigService.configs.language

    // Locale del sistema
    readonly property string systemLang: Qt.locale().name

    // Candidato antes de comprobar si existe el archivo de traducción
    readonly property string candidateLang: (userDefinedLang === "auto" || userDefinedLang === "")
        ? systemLang
        : userDefinedLang

    // Idioma resuelto (se actualiza tras comprobar existencia del archivo)
    property string language: "en_US"
    property var locale: Qt.locale(language)

    // Comprueba si existe el archivo de traducción para candidateLang.
    // Si no existe, usa "en_US" como fallback.
    Process {
        id: fileCheck

        command: ["test", "-f", Quickshell.shellPath("Core/i18n/" + root.candidateLang + ".json")]
        running: true

        onExited: code => {
            root.language = (code === 0) ? root.candidateLang : "en_US";
            fileManagment.reload();
        }
    }

    // Re-comprobar cuando cambie el idioma candidato (cambio de config o locale del sistema)
    onCandidateLangChanged: fileCheck.running = true

    // Diccionario con las traducciones cargadas
    property var translations: ({})

    FileView {
        id: fileManagment

        path: Quickshell.shellPath("Core/i18n/" + root.language + ".json")
        blockLoading: true
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
