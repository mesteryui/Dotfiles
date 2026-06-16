pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var configs: ({})

    FileView {
        id: fileManagment
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.configs = JSON.parse(fileManagment.text());
            } catch (e) {
                console.error("I18n error:", e);
            }
        }
    }

    function getConfig(key: string, default_key = ""): var {
        if (!root.configs) return default_key;
        
        const parts = key.split(".");
        let current = root.configs;
        
        for (const part of parts) {
            if (current === null || typeof current !== "object" || !(part in current)) {
                return default_key;
            }
            current = current[part];
        }
        
        return (current !== undefined && current !== null) ? current : default_key;
    }
}
