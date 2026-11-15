pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Idioma configurado. "auto" = usar el locale del sistema si está
    // entre los disponibles, si no en_US. Manual fuera de lista -> en_US.
    property string userDefinedLang: ConfigService.configs.language

    // Locale del sistema
    readonly property string systemLang: Qt.locale().name

    // Directorio con los locales: cada *.json aporta un código disponible.
    FolderListModel {
        id: localeDir

        folder: Qt.resolvedUrl("../i18n")
        nameFilters: ["*.json"]
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }

    // Códigos disponibles según ficheros presentes. Se completa sola al
    // añadir/quitar json; en_US siempre presente como referencia.
    readonly property list<string> available: {
        var out = [];
        for (let i = 0; i < localeDir.count; i++) {
            let n = localeDir.get(i, "fileName");
            if (n && String(n).endsWith(".json")) {
                const code = String(n).slice(0, -5);
                if (code !== "" && !out.includes(code))
                    out.push(code);
            }
        }
        if (!out.includes("en_US"))
            out.push("en_US");
        return out.sort();
    }

    // Candidato validado contra `available`. Sin alias: solo se normaliza
    // "-" a "_" (p. ej. "es-ES" -> "es_ES") por formato, no por familia.
    readonly property string candidateLang: {
        const normSys = root.systemLang.replace(/-/g, "_");
        const rawUser = root.userDefinedLang || "";
        if (rawUser === "auto" || rawUser === "")
            return root.available.includes(normSys) ? normSys : "en_US";
        const normUser = rawUser.replace(/-/g, "_");
        return root.available.includes(normUser) ? normUser : "en_US";
    }

    // Idioma resuelto (lo consumen los bindings para re-traducir la UI)
    property string language: "en_US"

    readonly property var locale: Qt.locale(language)

    // Diccionario con las traducciones cargadas. Si el candidato no está
    // en `available`, `candidateLang` ya es "en_US", así que basta un solo
    // FileView sin fallback adicional.
    property var translations: ({})

    readonly property string candidatePath: Quickshell.shellPath("Core/i18n/" + root.candidateLang + ".json")

    FileView {
        id: fileManagement

        path: root.candidatePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        onLoaded: {
            try {
                root.translations = JSON.parse(fileManagement.text());
            } catch (e) {
                console.error("I18n error:", e);
                root.translations = ({});
            }
            root.language = root.candidateLang;
            console.info("[I18n] system=" + root.systemLang + " candidate=" + root.candidateLang + " -> "
                         + root.language);
        }
        onLoadFailed: error => {
            // `candidateLang` ya está validado contra `available`: fuera de
            // lista => "en_US" y `candidatePath` apunta directo al inglés.
            // Este fallo solo es transitorio (borrado entre listado y carga
            // o en_US.json ausente). Al actualizarse `available` se recarga solo.
            root.translations = ({});
            root.language = "en_US";
            if (root.candidateLang !== "en_US")
                console.warn("I18n: no translation file for '" + root.candidateLang
                             + "', using English fallback");
        }
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
        return default_key;
    }

    // Nombre legible para el desplegable de idioma. Conocidos via
    // traducción, resto tal cual el código del fichero.
    function languageName(code: string): string {
        switch (code) {
        case "es_ES":
            return root.getTranslation("settings.system.language.es", "Español de España");
        case "en_US":
            return root.getTranslation("settings.system.language.en", "Ingles de EEUU");
        case "eo":
            return root.getTranslation("settings.system.language.eo", "Esperanto");
        default:
            return code;
        }
    }
}
