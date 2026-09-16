pragma Singleton

// --- SystemMenuRegistry (Singleton) ---
// Registro del menú de sistema estilo Omarchy.
// Une las secciones estáticas (un .js por menú Elephant en SystemMenu/)
// con las dinámicas (servidas en vivo por SystemMenuService).
//
// Añadir una sección estática nueva:
//   1. crea SystemMenu/MiSeccion.js con info() + entries()
//      (cada entrada: { id, title, tk, sub, sk, icon, act })
//   2. impórtala abajo y añádela a `staticModules`.
//
// i18n: títulos/subtítulos se resuelven aquí con I18nService usando las
// claves tk/sk (fallback al literal en español). El enlace a perfiles de
// energía muestra además el perfil actual en vivo.
//
// Secciones dinámicas (id → origen):
//   powerprofiles → servicio nativo PowerProfiles (ver SystemMenuService)
//   fastfetch      → fastfetch/layouts/*             (dynamic/fastfetch-configs.lua)
//   animations     → hypr/configs/animations/*.lua   (dynamic/animations-hypr.lua)

import qs.Core.Services as Services
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "SystemMenu/Main.js" as Main
import "SystemMenu/Screenshot.js" as Screenshot
import "SystemMenu/Configure.js" as Configure
import "SystemMenu/Appearance.js" as Appearance
import "SystemMenu/Packages.js" as Packages
import "SystemMenu/Setup.js" as Setup
import "SystemMenu/Games.js" as Games

Singleton {
    id: root

    readonly property var staticModules: [Main, Screenshot, Configure, Appearance, Packages, Setup, Games]
    readonly property var dynamicInfo: [
        { id: "powerprofiles", title: "Perfil de energía", tk: "sysmenu.sec_powerprofiles", icon: "battery_charging_full", parent: "configure" },
        { id: "fastfetch", title: "Tema Fastfetch", tk: "sysmenu.sec_fastfetch", icon: "terminal", parent: "appearance" },
        { id: "animations", title: "Animaciones Hyprland", tk: "sysmenu.sec_animations", icon: "animation", parent: "appearance" }
    ]

    function tr(key, fallback) {
        return Services.I18nService.getTranslation(key || "", fallback || "");
    }

    function sectionTitle(info) {
        return tr(info.tk, info.title);
    }

    // Etiqueta del perfil de energía actual (para mostrarla en el enlace).
    function powerLabel() {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return tr("battery.powersave", "Ahorro");
        case PowerProfile.Performance:
            return tr("battery.performance", "Rendimiento");
        default:
            return tr("battery.balanced", "Equilibrado");
        }
    }

    function sections() {
        const out = [];
        for (let i = 0; i < staticModules.length; i++) {
            const info = staticModules[i].info();
            out.push(Object.assign({}, info, { title: sectionTitle(info) }));
        }
        for (let j = 0; j < dynamicInfo.length; j++)
            out.push(Object.assign({}, dynamicInfo[j], { title: sectionTitle(dynamicInfo[j]) }));
        return out;
    }

    function sectionInfo(id) {
        const all = sections();
        for (let i = 0; i < all.length; i++)
            if (all[i].id === id)
                return all[i];
        return { id: "main", title: tr("sysmenu.sec_main", "Sistema"), icon: "tune", parent: "" };
    }

    // Entradas estáticas de una sección ([] si es dinámica).
    function staticEntries(id) {
        for (let i = 0; i < staticModules.length; i++)
            if (staticModules[i].info().id === id)
                return staticModules[i].entries();
        return [];
    }

    function isDynamic(id) {
        for (let i = 0; i < dynamicInfo.length; i++)
            if (dynamicInfo[i].id === id)
                return true;
        return false;
    }

    // Miga de pan desde la raíz hasta la sección (para el breadcrumb).
    function trail(id) {
        const byId = {};
        const all = sections();
        for (let i = 0; i < all.length; i++)
            byId[all[i].id] = all[i];
        const out = [];
        let cur = byId[id] || byId["main"];
        while (cur) {
            out.unshift({ id: cur.id, title: cur.title });
            cur = cur.parent ? byId[cur.parent] : null;
        }
        return out;
    }

    // Comando shell final de una entrada (lo que ejecuta AppLauncher).
    function shellOf(entry) {
        if (entry.act.type === "ipc")
            return "qs ipc call " + entry.act.call;
        return entry.act.cmd;
    }

    // Entrada estática → item de resultados del launcher.
    function toResultItem(entry, sectionTitle) {
        let sub = tr(entry.sk, entry.sub);
        // El enlace a perfiles muestra el perfil actual en vivo.
        if (entry.act.type === "section" && entry.act.id === "powerprofiles")
            sub += " · " + powerLabel();
        return {
            kind: "system", title: tr(entry.tk, entry.title), sub: sub,
            iconName: entry.icon, appIcon: "", ch: "", imagePath: "",
            cat: sectionTitle, shell: shellOf(entry),
            isSubmenu: entry.act.type === "section",
            section: entry.act.type === "section" ? entry.act.id : ""
        };
    }

    // Todas las estáticas aplanadas (búsqueda global con query).
    function flattenStatic() {
        const out = [];
        const all = sections();
        for (let i = 0; i < all.length; i++) {
            const items = staticEntries(all[i].id);
            for (let j = 0; j < items.length; j++)
                out.push(toResultItem(items[j], all[i].title));
        }
        return out;
    }
}
