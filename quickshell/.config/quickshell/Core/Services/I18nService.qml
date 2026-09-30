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
    // Normaliza variantes ("es", "es-ES", "es_MX") al nombre de archivo
    // ("es_ES") para no caer a en_US cuando Qt no devuelve el locale
    // completo. Igual para inglés ("en", "en_GB" → "en_US").
    readonly property string candidateLang: {
        const raw = (userDefinedLang === "auto" || userDefinedLang === "") ? systemLang : userDefinedLang;
        const norm = raw.replace("-", "_");
        if (norm === "es" || norm.startsWith("es_"))
            return "es_ES";
        if (norm === "en" || norm.startsWith("en_"))
            return "en_US";
        return norm;
    }

    // Idioma resuelto (lo consumen los bindings para re-traducir la UI)
    property string language: "en_US"
    readonly property var locale: Qt.locale(language)

    // Diccionario con las traducciones cargadas
    property var translations: ({})
    // Fallback inglés por clave: si el idioma cargado (p. ej. eo) no trae
    // una clave, se usa el valor de en_US antes que el default inline
    // (que suele estar en español y enmascaraba los huecos).
    property var fallbackTranslations: ({})

    // Si el candidato no tiene archivo, se carga el fallback inglés.
    property bool useFallback: false

    readonly property string candidatePath: Quickshell.shellPath("Core/i18n/" + root.candidateLang + ".json")
    readonly property string fallbackPath: Quickshell.shellPath("Core/i18n/en_US.json")

    FileView {
        id: fallbackFile

        path: root.fallbackPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.fallbackTranslations = JSON.parse(fallbackFile.text());
            } catch (e) {
                Log.error("I18n fallback error:", e);
                root.fallbackTranslations = ({});
            }
        }
        onLoadFailed: error => {
            Log.error("I18n error: missing fallback file:", fallbackFile.path);
            root.fallbackTranslations = ({});
        }
    }

    FileView {
        id: fileManagment

        path: root.useFallback ? root.fallbackPath : root.candidatePath
        blockLoading: true
        watchChanges: true
        printErrors: false
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

    // Al cambiar el candidato (config o locale) se reintenta su archivo.
    // Nota: candidateLang es readonly pero sí emite candidateLangChanged.
    onCandidateLangChanged: {
        root.useFallback = false;
    }

    function _lookup(dict, key: string): var {
        const parts = key.split(".");
        let current = dict;
        for (const part of parts) {
            if (current === undefined || current === null)
                return undefined;
            current = current[part];
        }
        return current;
    }

    function getTranslation(key: string, default_key = ""): var {
        const hit = root._lookup(root.translations, key);
        if (hit !== undefined && hit !== null)
            return hit;
        const fb = root._lookup(root.fallbackTranslations, key);
        if (fb !== undefined && fb !== null)
            return fb;
        return default_key;
    }
}
