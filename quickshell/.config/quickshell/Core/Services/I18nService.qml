pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../Log.js" as Log

Singleton {
    id: root

    // Idioma configurado. "auto" significa adaptar al idioma del sistema.
    property string userDefinedLang: ConfigService.configs.language

    // Locale del sistema
    readonly property string systemLang: Qt.locale().name

    // Candidato antes de comprobar si existe el archivo de traducción.
    // Normaliza variantes ("es", "es-ES") al nombre de archivo ("es_ES")
    // para no caer a en_US cuando Qt no devuelve el locale completo.
    readonly property string candidateLang: {
        const raw = (userDefinedLang === "auto" || userDefinedLang === "") ? systemLang : userDefinedLang;
        const norm = raw.replace("-", "_");
        if (norm === "es")
            return "es_ES";
        if (norm === "en")
            return "en_US";
        return norm;
    }

    // Idioma resuelto (lo consumen los bindings para re-traducir la UI)
    property string language: "en_US"
    property var locale: Qt.locale(language)

    // Diccionario con las traducciones cargadas
    property var translations: ({})

    // Si el candidato no tiene archivo, se carga el fallback inglés.
    property bool useFallback: false

    readonly property string candidatePath: Quickshell.shellPath("Core/i18n/" + root.candidateLang + ".json")
    readonly property string fallbackPath: Quickshell.shellPath("Core/i18n/en_US.json")

    // Al cambiar el candidato (config o locale) se reintenta su archivo.
    onCandidateLangChanged: {
        root.useFallback = false;
    }

    FileView {
        id: fileManagment

        path: root.useFallback ? root.fallbackPath : root.candidatePath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.translations = JSON.parse(fileManagment.text());
            } catch (e) {
                Log.error("I18n error:", e);
                root.translations = ({});
            }
            root.language = root.useFallback ? "en_US" : root.candidateLang;
            Log.info("[I18n] system=" + root.systemLang + " candidate=" + root.candidateLang + " -> " + root.language);
        }
        onLoadFailed: error => {
            if (!root.useFallback && root.candidateLang !== "en_US") {
                root.useFallback = true;
            } else {
                Log.error("I18n error: missing translation file:", fileManagment.path);
                root.translations = ({});
                root.language = "en_US";
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
