pragma Singleton

// --- SystemMenuRegistry = UnifiedMenuRegistry (Singleton) ---
// FACHADA ÚNICA del sistema unificado de menús personalizados.
// (Personalizado = todo lo que NO es Archivos, Aplicaciones, Calculadora,
// Web, Emojis, Clipboard.)
//
// Orígenes (el display no distingue ninguno, siempre pregunta aquí):
//   1. providers unificados → CustomMenuService (MenuProviders/System/*.qml
//      internos primero, MenuProviders/*.qml tuyos después; misma interfaz)
//   2. dinámicos en vivo    → SystemMenuService (powerprofiles, fastfetch,
//      animations)
//
// Crear un menú nuevo (única vía):
//   copia MenuProviders/MenuProvider.qml a MenuProviders/MiMenu.qml,
//   rellena sectionId/title/icon/parentId/entries (+ refresh() si es
//   dinámico) y recarga el shell. Sin tocar este archivo.
//
// i18n: títulos/subtítulos se resuelven aquí con I18nService usando las
// claves titleKey/subtitleKey (fallback a los literales en español). El enlace
// a perfiles de energía muestra además el perfil actual en vivo.
//
// LEGADO: SystemMenu/*.js (info()+entries()) queda como referencia; el
// Registry ya no los importa. La fuente de verdad son los *.qml unificados.

import qs.Core.Services as Services
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var dynamicInfo: [
        { sectionId: "powerprofiles", titleFallback: "Perfil de energía", titleKey: "sysmenu.sec_powerprofiles", iconName: "battery_charging_full", parentId: "configure" },
        { sectionId: "fastfetch", titleFallback: "Tema Fastfetch", titleKey: "sysmenu.sec_fastfetch", iconName: "terminal", parentId: "appearance" },
        { sectionId: "animations", titleFallback: "Animaciones Hyprland", titleKey: "sysmenu.sec_animations", iconName: "animation", parentId: "appearance" }
    ]

    function tr(key, fallback) {
        return Services.I18nService.getTranslation(key || "", fallback || "");
    }

    function sectionTitle(sectionInfo) {
        return tr(sectionInfo.titleKey, sectionInfo.titleFallback);
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
        const seen = {};
        // Providers unificados (internos primero, tuyos después; el store
        // ya dedupica, aquí solo se traduce el título).
        const customs = CustomMenuService.sectionInfos();
        for (let k = 0; k < customs.length; k++) {
            if (seen[customs[k].sectionId])
                continue;
            out.push(Object.assign({}, customs[k], { title: sectionTitle(customs[k]) }));
            seen[customs[k].sectionId] = true;
        }
        // Dinámicos en vivo (si colisionan con un provider, manda el
        // provider y se avisa; en la práctica no colisionan).
        for (let j = 0; j < dynamicInfo.length; j++) {
            if (seen[dynamicInfo[j].sectionId]) {
                console.warn("SystemMenuRegistry: sectionId duplicado '" + dynamicInfo[j].sectionId + "', se ignora el dinámico");
                continue;
            }
            out.push(Object.assign({}, dynamicInfo[j], { title: sectionTitle(dynamicInfo[j]) }));
            seen[dynamicInfo[j].sectionId] = true;
        }
        return out;
    }

    // true si la sección es interna (provider de MenuProviders/System/ o dinámica).
    // Los duplicados propios se ignoran en el store, así que basta con esto.
    function isBuiltinSection(sectionId) {
        if (CustomMenuService.isSystemSection(sectionId))
            return true;
        for (let j = 0; j < dynamicInfo.length; j++)
            if (dynamicInfo[j].sectionId === sectionId)
                return true;
        return false;
    }

    function sectionInfo(sectionId) {
        const all = sections();
        for (let i = 0; i < all.length; i++)
            if (all[i].sectionId === sectionId)
                return all[i];
        return { sectionId: "main", title: tr("sysmenu.sec_main", "Sistema"), iconName: "tune", parentId: "" };
    }

    // Entradas unificadas de una sección ([] si no hay o si es dinámica pura).
    function staticEntries(sectionId) {
        return CustomMenuService.entriesOf(sectionId);
    }

    // Items dinámicos internos de una sección (snapshot de SystemMenuService).
    // Se lee el snapshot y NO los ListModel en vivo: esos notifican por cada
    // item y reevaluar resultados con cada append disparaba binding loops.
    function builtinDynamicItems(sectionId, withCat) {
        const label = withCat ? sectionInfo(sectionId).title : "";
        const snap = SystemMenuService.dynSnapshot;
        const out = [];
        for (let i = 0; i < snap.length; i++) {
            const dynEntry = snap[i];
            if (dynEntry.section !== sectionId)
                continue;
            out.push({
                kind: "system", title: dynEntry.title, sub: dynEntry.sub,
                iconName: dynEntry.iconName, appIcon: "", ch: "",
                imagePath: (dynEntry.preview && dynEntry.preview !== "") ? ("file://" + dynEntry.preview) : "",
                cat: label,
                shell: dynEntry.native ? "" : SystemMenuService.shellFor(sectionId, dynEntry.value),
                nativeApply: dynEntry.native || "", nativeValue: dynEntry.nativeValue,
                isSubmenu: false, section: ""
            });
        }
        return out;
    }

    // ---- Fachada única para el display (AppLauncher) ----
    // Una sola vía para servir y refrescar menús, sean internos o propios,
    // estáticos o dinámicos. El display no distingue el origen.

    // Items listos para pintar de una sección (navegación sin query).
    function sectionResultItems(sectionId) {
        const out = [];
        const statics = staticEntries(sectionId);
        for (let i = 0; i < statics.length; i++)
            out.push(toResultItem(statics[i], ""));
        return out.concat(builtinDynamicItems(sectionId, false));
    }

    // Todo lo buscable del menú de sistema (búsqueda global con query).
    function systemSearchPool() {
        let pool = flattenStatic();
        for (let k = 0; k < dynamicInfo.length; k++)
            pool = pool.concat(builtinDynamicItems(dynamicInfo[k].sectionId, true));
        return pool;
    }

    // Refresca una sección si es dinámica (no-op en el resto).
    function refreshSection(sectionId) {
        SystemMenuService.refreshSection(sectionId);
        CustomMenuService.refreshSection(sectionId);
    }

    // Refresca todos los modelos live al abrir el launcher.
    function refreshAll() {
        SystemMenuService.refreshAll();
        CustomMenuService.refreshAll();
    }

    // Miga de pan desde la raíz hasta la sección (para el breadcrumb).
    function trail(sectionId) {
        const byId = {};
        const all = sections();
        for (let i = 0; i < all.length; i++)
            byId[all[i].sectionId] = all[i];
        const out = [];
        let cur = byId[sectionId] || byId["main"];
        while (cur) {
            out.unshift({ sectionId: cur.sectionId, title: cur.title });
            cur = cur.parentId ? byId[cur.parentId] : null;
        }
        return out;
    }

    // Comando shell final de una entrada (lo que ejecuta AppLauncher).
    function shellOf(entry) {
        if (entry.action.kind === "ipc")
            return "qs ipc call " + entry.action.ipcCall;
        return entry.action.shellCommand;
    }

    // Entrada unificada → item de resultados del launcher.
    // `previewPath` (menús con imagen) se expone como imagen para el
    // preview lateral (ver MenuModes.needsPreview).
    function toResultItem(entry, sectionLabel) {
        let subtitle = tr(entry.subtitleKey, entry.subtitleFallback);
        // El enlace a perfiles muestra el perfil actual en vivo.
        if (entry.action.kind === "section" && entry.action.targetSectionId === "powerprofiles")
            subtitle += " · " + powerLabel();
        return {
            kind: "system", title: tr(entry.titleKey, entry.titleFallback), sub: subtitle,
            iconName: entry.iconName, appIcon: "", ch: "",
            imagePath: entry.previewPath ? ("file://" + entry.previewPath) : "",
            cat: sectionLabel, shell: shellOf(entry),
            isSubmenu: entry.action.kind === "section",
            section: entry.action.kind === "section" ? entry.action.targetSectionId : ""
        };
    }

    // Todas las unificadas aplanadas (búsqueda global con query).
    function flattenStatic() {
        const out = [];
        const all = sections();
        for (let i = 0; i < all.length; i++) {
            // Las dinámicas puras no tienen entries unificadas; se añaden
            // aparte en systemSearchPool() vía builtinDynamicItems().
            const items = staticEntries(all[i].sectionId);
            for (let j = 0; j < items.length; j++)
                out.push(toResultItem(items[j], all[i].title));
        }
        return out;
    }
}
