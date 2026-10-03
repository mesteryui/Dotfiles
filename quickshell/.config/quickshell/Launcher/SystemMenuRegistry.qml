pragma Singleton

// --- SystemMenuRegistry = UnifiedMenuRegistry (Singleton) ---
// FACHADA ÚNICA del sistema unificado de menús personalizados.
// (Personalizado = todo lo que NO es Archivos, Aplicaciones, Calculadora,
// Web, Emojis, Clipboard.)
//
// Origen único (el display no distingue ninguno, siempre pregunta aquí):
//   providers unificados → MenuStore: todo menú usa el componente
//   base Launcher/MenuDefinition.qml (módulo qs.Launcher) como raíz, sea
//   estático (entries fijas) o dinámico (entries generadas en refresh()).
//   Internos: MenuProviders/System/*.qml (cargan primero).
//   Tuyos: MenuProviders/*.qml (vía new-menu.sh o a mano).
//
// Crear un menú nuevo (vía clásica, estático o dinámico):
//   ejecuta MenuProviders/new-menu.sh MiMenu "Mi menú" (o escribe un
//   MenuDefinition { } a mano), rellena entries y guarda: la recarga en vivo
//   lo aplica en ~2 s. Sin tocar este archivo y sin recargar todo el shell.
//   Dinámico = implementa refresh() reasignando entries entero
//   (ver MenuProviders/System/FastfetchMenu.qml).
//
// Reactividad: las funciones que sirven items/secciones leen
// MenuStore.revision, así cualquier reload() reevalúa los bindings
// del launcher automáticamente.
//
// i18n: títulos/subtítulos se resuelven aquí con I18nService usando las
// claves titleKey/subtitleKey (fallback a los literales en español).
// Esta fachada es genérica: no conoce ningún menú concreto; cada provider
// describe lo suyo con entradas shell()/ipc()/submenu().

import qs.Core.Services as Services
import QtQuick
import Quickshell
import "Base/ShellUtils.js" as ShellUtils

Singleton {
    id: root

    function tr(key, fallback) {
        return Services.I18nService.getTranslation(key || "", fallback || "");
    }

    function sectionTitle(sectionInfo) {
        return tr(sectionInfo.titleKey, sectionInfo.titleFallback);
    }

    // Memoización behavior-preserving: sections()/flattenStatic() se
    // llamaban por cada tecla y reconstruían + traducían todo. La caché
    // se invalida con revision (contenido) e idioma (textos); la lectura
    // explícita de ambas conserva la reactividad de los bindings.
    // OJO: la caché vive en CAMPOS de un objeto JS y solo se muta, nunca
    // se reasigna la propiedad: reasignar notificaría y, como estas
    // funciones se llaman desde bindings que leen la caché, QML avisaría
    // "Binding loop detected" aunque convergiera.
    property var _memo: ({
        sectionsKey: "", sectionsVal: [],
        poolKey: "", poolVal: [], poolRefs: [],
        sectionRev: "", sectionCache: ({})
    })

    function memoKey() {
        return MenuStore.revision + "|" + Services.I18nService.language;
    }

    function sections() {
        const key = root.memoKey();
        if (key === root._memo.sectionsKey)
            return root._memo.sectionsVal;
        const out = [];
        const seen = {};
        // Dependencia reactiva: tras un reload() este binding se reevalúa.
        const rev = MenuStore.revision;
        // Vía única: providers unificados (internos primero, tuyos después;
        // el store ya dedupica, aquí solo se traduce el título).
        // Estáticos y dinámicos llegan igual: los dinámicos regeneran sus
        // entries en refresh() y la lectura de la propiedad invalida sola.
        const customs = MenuStore.sectionInfos();
        for (let k = 0; k < customs.length; k++) {
            if (seen[customs[k].sectionId])
                continue;
            out.push(Object.assign({}, customs[k], { title: sectionTitle(customs[k]) }));
            seen[customs[k].sectionId] = true;
        }
        root._memo.sectionsKey = key;
        root._memo.sectionsVal = out;
        return out;
    }

    // true si la sección es interna (provider de MenuProviders/System/).
    // Los duplicados propios se ignoran en el store, así que basta con esto.
    function isBuiltinSection(sectionId) {
        return MenuStore.isSystemSection(sectionId);
    }

    function sectionInfo(sectionId) {
        const all = sections();
        for (let i = 0; i < all.length; i++)
            if (all[i].sectionId === sectionId)
                return all[i];
        return { sectionId: "main", title: tr("sysmenu.section_main", "Sistema"), iconName: "tune", parentId: "" };
    }

    // Entradas unificadas de una sección ([] si no hay).
    // Vale para estáticas y dinámicas: ambas exponen `entries`.
    function staticEntries(sectionId) {
        return MenuStore.entriesOf(sectionId);
    }

    // ---- Fachada única para el display (AppLauncher) ----
    // Una sola vía para servir y refrescar menús, sean internos o propios,
    // estáticos o dinámicos. El display no distingue el origen.

    // Items listos para pintar de una sección (navegación sin query).
    // La caché se invalida también si el provider reasignó `entries`
    // (los dinámicos lo hacen sin bump de revision): se lee entriesOf
    // siempre (dependencia reactiva) y se compara la referencia.
    function sectionResultItems(sectionId) {
        // Dependencia reactiva (ver sections()).
        const rev = MenuStore.revision;
        const statics = staticEntries(sectionId);
        const key = sectionId + "|" + root.memoKey();
        const hit = root._memo.sectionCache[sectionId];
        if (hit && hit.key === key && hit.src === statics)
            return hit.val;
        const out = [];
        for (let i = 0; i < statics.length; i++)
            out.push(toResultItem(statics[i], ""));
        if (rev !== root._memo.sectionRev) {
            root._memo.sectionRev = rev;
            root._memo.sectionCache = {};
        }
        root._memo.sectionCache[sectionId] = { key: key, src: statics, val: out };
        return out;
    }

    // Todo lo buscable del menú de sistema (búsqueda global con query).
    function systemSearchPool() {
        return flattenStatic();
    }

    // Refresca una sección si es dinámica (no-op en las estáticas:
    // su refresh() es vacío por defecto en MenuDefinition).
    function refreshSection(sectionId) {
        MenuStore.refreshSection(sectionId);
    }

    // Guarda temporal del refresco completo: reabrir en <8 s no regenera
    // (entrar en una sección vía refreshSection() sigue siendo siempre
    // fresco; reloadMenus fuerza vía reload()). Las fuentes dinámicas
    // cambian poco (layouts/animaciones) y el perfil de energía se
    // actualiza solo por D-Bus en su provider.
    property double lastRefreshAll: 0

    // Refresca todos los providers al abrir el launcher.
    // Además dispara la comprobación de cambios en disco (recarga en
    // vivo: si editaste un provider, se aplica solo).
    function refreshAll() {
        if (Date.now() - root.lastRefreshAll < 8000)
            return;
        root.lastRefreshAll = Date.now();
        MenuStore.refreshAll();
        MenuStore.checkNow();
    }

    // Recarga completa de menús sin recargar el shell (vía IPC:
    // `qs ipc call launcher reloadMenus`). Re-escanea providers en disco,
    // refresca los dinámicos y devuelve diagnóstico.
    function reloadMenus(): string {
        const started = MenuStore.reload();
        const infos = MenuStore.sectionInfos();
        const ids = [];
        for (let i = 0; i < infos.length; i++)
            ids.push(infos[i].sectionId);
        // Ojo: el redescubrimiento es asíncrono (Process ls); los nuevos
        // providers aparecen solos al terminar vía revision. Este resumen
        // describe el estado previo + si se lanzó el escaneo.
        return (started ? "rescanning" : "already-scanning")
            + " menus=" + ids.length + " rev=" + MenuStore.revision
            + " errors=" + MenuStore.loadErrors
            + (MenuStore.lastError !== "" ? " lastError=" + MenuStore.lastError : "")
            + " [" + ids.join(",") + "]";
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
    // Las secciones no tienen shell ("").
    function shellOf(entry) {
        if (!entry || !entry.action)
            return "";
        if (entry.action.kind === "ipc")
            return "qs ipc call " + entry.action.ipcCall;
        if (entry.action.kind === "shell")
            return entry.action.shellCommand;
        return "";
    }

    // Entrada unificada → item de resultados del launcher.
    // `previewPath` (menús con imagen) se expone como imagen para el
    // preview lateral (ver MenuModes.needsPreview).
    function toResultItem(entry, sectionLabel) {
        const kind = (entry && entry.action && entry.action.kind) || "";
        return {
            kind: "system", title: tr(entry.titleKey, entry.titleFallback), sub: tr(entry.subtitleKey, entry.subtitleFallback),
            iconName: entry.iconName, appIcon: "", ch: "",
            imagePath: entry.previewPath ? ShellUtils.fileUrl(entry.previewPath) : "",
            cat: sectionLabel, shell: shellOf(entry),
            isSubmenu: kind === "section",
            section: kind === "section" ? entry.action.targetSectionId : ""
        };
    }

    // Todas las unificadas aplanadas (búsqueda global con query).
    // Igual que sectionResultItems: si algún provider dinámico reasignó
    // sus `entries`, las referencias dejan de coincidir y se reconstruye.
    function flattenStatic() {
        const key = root.memoKey();
        // Dependencia reactiva (ver sections()).
        const rev = MenuStore.revision;
        const all = sections();
        const refs = [];
        for (let i = 0; i < all.length; i++)
            refs.push(staticEntries(all[i].sectionId));
        if (key === root._memo.poolKey && root._memo.poolRefs.length === refs.length) {
            let same = true;
            for (let k = 0; k < refs.length; k++)
                if (root._memo.poolRefs[k] !== refs[k]) {
                    same = false;
                    break;
                }
            if (same)
                return root._memo.poolVal;
        }
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const items = refs[i];
            for (let j = 0; j < items.length; j++)
                out.push(toResultItem(items[j], all[i].title));
        }
        root._memo.poolKey = key;
        root._memo.poolRefs = refs;
        root._memo.poolVal = out;
        return out;
    }
}
