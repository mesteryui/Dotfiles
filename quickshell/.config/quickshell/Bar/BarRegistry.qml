pragma Singleton

import QtQuick
import Quickshell
import qs.Core.Services as Services

// BarRegistry: orden e ids de módulos de la barra. Sin faces/ ni variantes (fase 1).
// El orden vive en ConfigService.configs.bar.{left,center,right,sideTop,sideCenter,sideBottom}.
// MainBar.qml y el futuro SideBar.qml ordenan con sectionModules() y crean con
// Components estáticos (ver NOTA en MainBar.qml: Loader `source:url` no resuelve qs.*).
// faceFile()/variantFaceFile() quedan como API informativa, no para Loader.source.
Singleton {
    id: root

    // Canónicos existentes en Bar/Items/. verticalFace = mismo fichero
    // hasta que haya SideBar con caras dedicadas (preparado el campo).
    property var types: ({
        "launcher": { name: "Launcher", horizontalFace: "Items/Launcher.qml", verticalFace: "Items/Launcher.qml" },
        "workspaces": { name: "Workspaces", horizontalFace: "Items/Workspaces.qml", verticalFace: "Items/Workspaces.qml" },
        "submap": { name: "Submap", horizontalFace: "Items/HyprlandSubmap.qml", verticalFace: "Items/HyprlandSubmap.qml" },
        "weather": { name: "Weather", horizontalFace: "Items/Weather.qml", verticalFace: "Items/Weather.qml" },
        "mpris": { name: "Media", horizontalFace: "Items/MprisPlayer.qml", verticalFace: "Items/MprisPlayer.qml" },
        "updates": { name: "Updates", horizontalFace: "Items/UpdateCounter.qml", verticalFace: "Items/UpdateCounter.qml" },
        "clock": { name: "Clock", horizontalFace: "Items/Clock.qml", verticalFace: "Items/Clock.qml" },
        "tray": { name: "Tray", horizontalFace: "Items/SysTray.qml", verticalFace: "Items/SysTray.qml" },
        "network": { name: "Network", horizontalFace: "Items/Network.qml", verticalFace: "Items/Network.qml" },
        "bluetooth": { name: "Bluetooth", horizontalFace: "Items/Bluetooth.qml", verticalFace: "Items/Bluetooth.qml" },
        "battery": { name: "Battery", horizontalFace: "Items/Battery.qml", verticalFace: "Items/Battery.qml" },
        "volume": { name: "Volume", horizontalFace: "Items/Volume.qml", verticalFace: "Items/Volume.qml" },
        "caffeine": { name: "Caffeine", horizontalFace: "Items/Caffeine.qml", verticalFace: "Items/Caffeine.qml" },
        "notifications": { name: "Notifications", horizontalFace: "Items/Notifications.qml", verticalFace: "Items/Notifications.qml" }
    })

    // Orden por defecto (única fuente para el fallback pre-ready).
    // Debe coincidir con los defaults de ConfigService.configs.bar.
    readonly property var defaultSections: ({
        "left": ["launcher", "workspaces", "submap"],
        "center": ["weather", "mpris", "updates", "clock"],
        "right": ["tray", "network", "bluetooth", "battery", "volume"],
        "sideTop": ["launcher", "workspaces"],
        "sideCenter": ["clock"],
        "sideBottom": ["network", "bluetooth", "battery", "volume"]
    })

    function normalizeId(id) {
        if (!id)
            return "";
        let s = String(id).toLowerCase().trim();
        if (s === "timedate" || s === "time" || s === "clock")
            return "clock";
        if (s === "mprisplayer" || s === "media" || s === "player")
            return "mpris";
        if (s === "systray" || s === "tray")
            return "tray";
        if (s === "wifi" || s === "network")
            return "network";
        if (s === "bt")
            return "bluetooth";
        if (s === "bat")
            return "battery";
        if (s === "vol")
            return "volume";
        if (s === "submap" || s === "hyprlandsubmap" || s === "focus")
            return "submap";
        if (s === "updates" || s === "updatecounter" || s === "update")
            return "updates";
        if (s === "notif" || s === "notification")
            return "notifications";
        return s;
    }

    function isKnown(moduleId) {
        return !!types[normalizeId(moduleId)];
    }

    // Algunos módulos se ocultan solos (misma condición que su `visible`
    // interno en Items/): excluirlos del modelo equivale al comportamiento
    // anterior (hijos invisibles saltados por el layout, sin hueco ni spacing).
    function isModuleActive(moduleId) {
        switch (normalizeId(moduleId)) {
        case "submap":
            return Services.HyprlandSubmap.activeSubmap !== "";
        case "updates":
            return Services.UpdatesTracking.updateCount > 0 || Services.UpdatesTracking.checking;
        default:
            return true;
        }
    }

    function faceFile(moduleId, isSide) {
        let norm = normalizeId(moduleId);
        let t = types[norm];
        if (!t) {
            console.warn("BarRegistry: módulo desconocido '" + moduleId + "' (normalizado '" + norm + "'), se omite");
            return "";
        }
        let file = isSide ? (t.verticalFace || t.horizontalFace) : (t.horizontalFace || t.verticalFace);
        return file ? Qt.resolvedUrl(file) : "";
    }

    // Stubs compatibles con el diseño completo (variantes/faces).
    // Fase 1: siempre "default", delegan a faceFile().
    function defaultVariant(moduleId) {
        return "default";
    }

    function getModuleVariant(moduleId, isSide) {
        return "default";
    }

    function variantFaceFile(moduleId, variant, isSide) {
        return faceFile(moduleId, isSide);
    }

    function moduleIds() {
        return Object.keys(types);
    }

    function moduleList() {
        return Object.keys(types).map(k => Object.assign({ id: k }, types[k]));
    }

    function registerModule(moduleId, def) {
        if (!moduleId || !def)
            return;
        let norm = normalizeId(moduleId);
        let updated = Object.assign({}, types);
        updated[norm] = def;
        types = updated;
    }

    function unregisterModule(moduleId) {
        let norm = normalizeId(moduleId);
        if (!types[norm])
            return;
        let updated = Object.assign({}, types);
        delete updated[norm];
        types = updated;
    }

    // Lee el orden desde ConfigService (bar.layout) con fallback al layout actual
    // (primeros frames con !ready, igual que Bar.qml). Avisa de ids
    // desconocidos y de valores con tipo inválido en vez de omitir en silencio.
    function sectionModules(section) {
        let raw = defaultSections[section] ? defaultSections[section].slice() : [];
        if (Services.ConfigService.ready) {
            const layout = Services.ConfigService.configs.bar.layout;
            if (layout !== undefined && layout[section] !== undefined) {
                const v = layout[section];
                // list<string> llega como array-like: copia a mano. Un string
                // suelto se acepta como lista de un elemento; otro tipo usa el defecto.
                if (typeof v === "string") {
                    raw = [v];
                } else if (v && typeof v.length === "number") {
                    raw = [];
                    for (let i = 0; i < v.length; i++)
                        raw.push(String(v[i]));
                } else {
                    console.warn("BarRegistry: '" + section + "' no es una lista, se usa el orden por defecto");
                    raw = defaultSections[section] ? defaultSections[section].slice() : [];
                }
            }
        }
        const known = [];
        const unknown = [];
        for (let i = 0; i < raw.length; i++) {
            if (isKnown(raw[i]))
                known.push(String(raw[i]));
            else
                unknown.push(String(raw[i]));
        }
        if (unknown.length > 0)
            console.warn("BarRegistry: módulos desconocidos en '" + section + "' se omiten: " + unknown.join(", "));
        // Los inactivos (submap sin submapa, updates a cero) se excluyen en
        // silencio: es estado normal, no error de config.
        return known.filter(id => isModuleActive(id));
    }
}
