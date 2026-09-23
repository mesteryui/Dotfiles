// --- EmojiService (Singleton) ---
// Selector de emojis serio para el launcher (modo `.`). El catálogo NO
// está hardcodeado en ningún .js: se genera en runtime con
// `python3 scripts/emoji-dump.py` (proceso, streaming TSV):
//   - emojis: librería `emoji` de PyPI (fully-qualified, sin tonos),
//   - símbolos: stdlib `unicodedata` (flechas, mates, moneda, dingbats),
//   - grupo amplio por clasificador (caras/gente/cosas/simbolos) y
//     keywords derivadas del nombre (+ sinónimos), todo en el script.
// Encima solo va tu capa `EmojiCustom.js` (prioridad máxima, es tu
// config, no datos). Sin duplicar por `ch`.
//   - Búsqueda con ranking propio (exacto > prefijo nombre > prefijo
//     keyword > contiene + boost de recientes/favoritos) y filtro por
//     grupo: `. g:cosas game` o `. g:simbolos arrow`.
//   - Recientes + favoritos persistidos en
//     ~/.local/state/quickshell/emoji.json (vía FileView, como
//     Persistent.qml). El copy centralizado (`wl-copy`) registra uso.
//   - Items listos para pintar (`queryItems`) + metadatos (codepoints
//     U+XXXX, grupo, keywords).
//
// AppLauncher solo llama a `queryItems()` / `copy()` / `groups()` y lee
// `revision` como dependencia reactiva (igual que MenuStore).

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Modules
import qs.Core.Services
import "../Core/Log.js" as Log
import "EmojiCustom.js" as EmojiCustom

Singleton {
    id: root

    // Se incrementa en cada cambio (base lista, merge del generador,
    // recientes/favoritos). AppLauncher lo lee en emojiResults() para
    // reevaluar solo.
    property int revision: 0
    property bool ready: false

    // Base cruda fusionada: [{ ch, name, kw, group, src }]
    // src: 0 = custom (tu config), 1 = runtime (programa/librería).
    property var base: []
    property var byChar: ({})
    property bool baseBuilt: false

    // Estado del generador (proceso python).
    property string libVersion: ""
    property string libStatus: "pending"
    property int libCount: 0
    property int symbolCount: 0
    property int customCount: 0

    function sourceInfo() {
        return "custom=" + root.customCount + " lib=" + root.libCount
            + " symbols=" + root.symbolCount
            + " status=" + root.libStatus + (root.libVersion !== "" ? "(" + root.libVersion + ")" : "")
            + " total=" + root.base.length;
    }

    // ---- grupos (pocos y amplios, para que los chips quepan en una fila) ----
    readonly property var groupMeta: [
        { id: "caras", label: "Caras", icon: "sentiment_satisfied" },
        { id: "gente", label: "Gente", icon: "waving_hand" },
        { id: "cosas", label: "Cosas", icon: "inventory_2" },
        { id: "simbolos", label: "Símbolos", icon: "grade" }
    ]

    // Alias de grupos antiguos (por si tecleas `g:tech` de memoria) y
    // normalización de acentos (`g:símbolos` vale igual que `g:simbolos`).
    readonly property var groupAlias: ({
        "smileys": "caras",
        "gestures": "gente", "hearts": "gente",
        "objects": "cosas", "food": "cosas", "activity": "cosas",
        "tech": "cosas", "nature": "cosas", "travel": "cosas",
        "symbols": "simbolos", "arrows": "simbolos", "effects": "simbolos"
    })

    function normGroup(g) {
        let n = String(g || "").toLowerCase();
        n = n.replace(/[áàä]/g, "a").replace(/[éèë]/g, "e").replace(/[íìï]/g, "i")
             .replace(/[óòö]/g, "o").replace(/[úùü]/g, "u").replace(/ñ/g, "n");
        return root.groupAlias[n] || n;
    }

    // Grupos con conteo vivo para pintar chips. Los pseudo-grupos
    // `recent` / `fav` van primero (solo si tienen contenido).
    function groups() {
        const counts = {};
        for (let i = 0; i < root.base.length; i++) {
            const g = root.base[i].group || "";
            if (g !== "")
                counts[g] = (counts[g] || 0) + 1;
        }
        const out = [];
        const recents = root.recentList();
        const favs = root.favoriteList();
        if (recents.length > 0)
            out.push({ id: "recent", label: "Recientes", icon: "history", count: recents.length });
        if (favs.length > 0)
            out.push({ id: "fav", label: "Favoritos", icon: "star", count: favs.length });
        for (let m = 0; m < root.groupMeta.length; m++) {
            const meta = root.groupMeta[m];
            const c = counts[meta.id] || 0;
            if (c > 0)
                out.push({ id: meta.id, label: meta.label, icon: meta.icon, count: c });
        }
        return out;
    }

    function groupLabel(id) {
        if (id === "recent")
            return "Recientes";
        if (id === "fav")
            return "Favoritos";
        const nid = root.normGroup(id);
        for (let m = 0; m < root.groupMeta.length; m++)
            if (root.groupMeta[m].id === nid)
                return root.groupMeta[m].label;
        return id === "" ? "Emoji" : id;
    }

    // ---- base (construcción perezosa, una sola vez) ----
    // Los extras de la librería se guardan aparte para reaplicarlos
    // si las capas .js cambian en disco (recarga en vivo).
    property var libExtras: []

    function buildLayers() {
        const seen = {};
        const items = [];
        let custom = 0;
        const list = EmojiCustom.getEmojis();
        for (let i = 0; i < list.length; i++) {
            const e = list[i];
            const ch = e && e.ch;
            if (!ch || seen[ch])
                continue;
            seen[ch] = true;
            items.push({ ch: ch, name: e.name || "", kw: e.kw || "", group: e.group || "", src: 0 });
            custom++;
        }
        return { items: items, seen: seen, custom: custom };
    }

    function applyLibExtras(items, seen) {
        let added = 0;
        for (let i = 0; i < root.libExtras.length; i++) {
            const e = root.libExtras[i];
            if (!e || !e.ch || seen[e.ch])
                continue;
            seen[e.ch] = true;
            items.push(e);
            added++;
        }
        return added;
    }
    function ensureBase() {
        if (root.baseBuilt)
            return root.base;
        const layers = root.buildLayers();
        root.applyLibExtras(layers.items, layers.seen);
        root.base = layers.items;
        root.byChar = layers.seen;
        root.customCount = layers.custom;
        root.baseBuilt = true;
        // `ready` solo cuando el generador terminó (libStatus): antes de
        // eso la base solo trae tu config. La UI reacciona a `revision`.
        if (root.libStatus !== "pending")
            root.ready = true;
        root.revision += 1;
        return layers.items;
    }

    // Recarga en vivo SIN polling: FileView vigila EmojiCustom.js con
    // notificaciones del sistema de ficheros (antes: `stat` cada 3 s).
    // Se reconstruye la capa custom y se reaplica lo generado encima.
    function rebuildCustom() {
        root.baseBuilt = false;
        root.ensureBase();
    }

    FileView {
        id: customWatch

        path: Directories.config + "/quickshell/Launcher/EmojiCustom.js"
        watchChanges: true
        onFileChanged: {
            // Pequeño respiro por si el editor escribe en varios pasos.
            customReloadTimer.restart();
        }
        onLoadFailed: error => {
            // Instalación fresca sin capa custom: no es un error.
            if (error !== FileViewError.FileNotFound)
                Log.warn("EmojiService: no se pudo leer EmojiCustom.js: " + error);
        }
    }

    Timer {
        id: customReloadTimer

        interval: 300
        repeat: false
        onTriggered: root.rebuildCustom()
    }

    // ---- persistencia (recientes + favoritos) ----
    property alias store: emojiStore
    // Recientes acotados: tope en memoria/disco y caducidad. No tiene
    // sentido persistirlos meses ni sin límite.
    property int maxRecents: 12
    property int recentsTtlSec: 2592000 // 30 días

    function recentList() {
        const v = emojiStore.recents;
        const out = [];
        if (v && typeof v.length === "number")
            for (let i = 0; i < v.length; i++)
                if (typeof v[i] === "string" && v[i] !== "")
                    out.push(v[i]);
        return out;
    }

    function favoriteList() {
        const v = emojiStore.favorites;
        const out = [];
        if (v && typeof v.length === "number")
            for (let i = 0; i < v.length; i++)
                if (typeof v[i] === "string" && v[i] !== "")
                    out.push(v[i]);
        return out;
    }

    function isFavorite(ch) {
        return root.favoriteList().indexOf(ch) >= 0;
    }

    function toggleFavorite(ch) {
        if (!ch)
            return false;
        const favs = root.favoriteList();
        const i = favs.indexOf(ch);
        let nowFav;
        if (i >= 0) {
            favs.splice(i, 1);
            nowFav = false;
        } else {
            favs.push(ch);
            nowFav = true;
        }
        emojiStore.favorites = favs;
        root.revision += 1;
        return nowFav;
    }

    function clearRecents() {
        emojiStore.recents = [];
        emojiStore.recentsStamp = 0;
        root.revision += 1;
    }

    // Poda por tope y caducidad (se aplica al cargar y al registrar uso).
    function pruneRecents() {
        var rec = root.recentList();
        var changed = false;
        if (rec.length > root.maxRecents) {
            emojiStore.recents = rec.slice(0, root.maxRecents);
            changed = true;
        }
        var stamp = emojiStore.recentsStamp || 0;
        var now = Date.now() / 1000;
        if (stamp > 0 && now - stamp > root.recentsTtlSec) {
            emojiStore.recents = [];
            emojiStore.recentsStamp = 0;
            changed = true;
        } else if (rec.length > 0 && stamp === 0) {
            emojiStore.recentsStamp = now;
            changed = true;
        }
        if (changed)
            root.revision += 1;
    }

    function recordUse(ch) {
        if (!ch)
            return;
        const rec = root.recentList();
        const i = rec.indexOf(ch);
        if (i >= 0)
            rec.splice(i, 1);
        rec.unshift(ch);
        emojiStore.recents = rec.slice(0, root.maxRecents);
        emojiStore.recentsStamp = Date.now() / 1000;
        root.revision += 1;
    }

    // Misma política de debounce que Persistent.qml (100 ms): coalesca
    // escrituras/recargas sin cambiar el formato del JSON.
    Timer {
        id: writeTimer
        interval: 100
        repeat: false
        onTriggered: emojiFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: emojiFile.reload()
    }

    FileView {
        id: emojiFile
        watchChanges: true
        path: Directories.state + "/quickshell/emoji.json"
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: {
            root.pruneRecents();
            root.revision += 1;
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                writeTimer.restart();
            else
                Log.warn("EmojiService: no se pudo leer emoji.json: " + error);
        }

        JsonAdapter {
            id: emojiStore
            property list<string> recents: []
            property double recentsStamp: 0
            property list<string> favorites: []
        }
    }

    // ---- generador: programa + librerías vía proceso ----
    // UN SOLO proceso al arrancar: `scripts/emoji-dump.py --all` vuelca
    //   #VERSION \t <versión de la librería `emoji`>
    //   CH \t NAME \t GROUP \t KEYWORDS   (una línea por entrada)
    //   #SYN / #SECTION                   (sinónimos y secciones)
    // (emojis de la librería `emoji` + símbolos de `unicodedata`).
    readonly property string dumpScript: Directories.config + "/quickshell/Launcher/scripts/emoji-dump.py"

    property var libLines: []

    // Arranque perezoso: el proceso python NO corre en boot (Component
    // solo deja lista tu capa custom, instantánea). AppLauncher llama a
    // ensureLib() al abrirse; la UI muestra tu config al momento y se
    // reevalúa sola vía `revision` cuando el generador termina.
    property bool libRequested: false

    function ensureLib() {
        if (root.libStatus !== "pending" || root.libRequested)
            return root.libStatus === "ok";
        root.libRequested = true;
        return root.refreshFromLib();
    }

    function refreshFromLib() {
        if (libProc.running)
            return false;
        libProc.running = true;
        return true;
    }

    Process {
        id: libProc
        command: ["python3", root.dumpScript, "--all"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line !== "")
                    root.libLines.push(line);
            }
        }
        onRunningChanged: {
            if (running)
                root.libLines = [];
        }
        onExited: code => {
            if (code !== 0) {
                root.libStatus = "error";
                return;
            }
            root.mergeLibLines(root.libLines);
        }
    }

    function mergeLibLines(lines) {
        root.ensureBase();
        const fresh = [];
        let lib = 0, sym = 0, inSymbols = false;
        for (let i = 0; i < lines.length; i++) {
            const cols = lines[i].split("\t");
            if (cols.length === 2 && cols[0] === "#VERSION") {
                if (cols[1] !== "")
                    root.libVersion = cols[1];
                continue;
            }
            if (cols.length === 3 && cols[0] === "#SYN" && cols[1] !== "") {
                const words = cols[2].split(" ").filter(w => w !== "");
                if (words.length > 0)
                    root.querySyn[cols[1].toLowerCase()] = words;
                continue;
            }
            if (cols.length === 2 && cols[0] === "#SECTION") {
                inSymbols = cols[1] === "symbols";
                continue;
            }
            if (cols.length < 3)
                continue;
            const ch = cols[0];
            const name = (cols[1] || "").trim();
            const group = (cols[2] || "").trim();
            const kw = (cols[3] || "").trim();
            if (!ch || !name || root.byChar[ch])
                continue;
            root.byChar[ch] = true;
            const entry = { ch: ch, name: name, kw: kw !== "" ? kw : name.toLowerCase(), group: group, src: 1 };
            fresh.push(entry);
            root.base.push(entry);
            if (inSymbols)
                sym++;
            else
                lib++;
        }
        if (fresh.length > 0) {
            root.libExtras = root.libExtras.concat(fresh);
            // Reasignación entera: invalida los bindings que leen la base.
            root.base = root.base.slice();
        }
        root.libCount = lib;
        root.symbolCount = sym;
        root.libStatus = "ok";
        root.ready = true;
        root.revision += 1;
    }

    Component.onCompleted: {
        // Solo la capa custom (local, inmediata). La librería/símbolos
        // arrancan con ensureLib() al primer uso (ver arriba).
        root.ensureBase();
    }

    // ---- helpers ----
    // Sin shellEscape local: la copia va por ClipboardService.copyText
    // (misma semántica; ver Launcher/Base/ShellUtils.js).

    function codepoints(ch) {
        const out = [];
        const s = String(ch);
        for (let i = 0; i < s.length;) {
            const cp = s.codePointAt(i);
            out.push("U+" + cp.toString(16).toUpperCase().padStart(4, "0"));
            i += cp > 0xFFFF ? 2 : 1;
        }
        return out.join(" ");
    }

    function findRaw(ch) {
        const items = root.ensureBase();
        for (let i = 0; i < items.length; i++)
            if (items[i].ch === ch)
                return items[i];
        return null;
    }

    // Copia al portapapeles y registra uso (vía única desde AppLauncher).
    function copy(ch) {
        if (!ch)
            return false;
        ClipboardService.copyText(ch);
        root.recordUse(ch);
        return true;
    }

    // Puntuación de un item contra la query ya normalizada.
    // Exacto > palabra exacta > prefijo de nombre > prefijo de keyword >
    // contiene. La palabra exacta (95) va ANTES que el prefijo para que un
    // token real ("lol"→😂 vía sinónimo "joy", "cry"→😿) gane a prefijos
    // accidentales ("joystick", "crystal ball", "lollipop").
    function scoreRaw(it, q) {
        const nm = (it.name || "").toLowerCase();
        const kw = (it.kw || "").toLowerCase();
        const gr = (it.group || "").toLowerCase();
        if (nm === q)
            return 100;
        if (q.length >= 2 && q.indexOf(" ") < 0) {
            const allWords = (nm + " " + kw).split(/[\s_/-]+/);
            if (allWords.indexOf(q) >= 0)
                return 95;
        }
        if (nm.startsWith(q))
            return 90;
        const words = kw.split(/[\s_/-]+/);
        for (let w = 0; w < words.length; w++)
            if (words[w].startsWith(q) && q.length >= 2)
                return 80;
        if (nm.indexOf(q) >= 0)
            return 70;
        if (kw.indexOf(q) >= 0)
            return 60;
        // Grupos normalizados: `tech` sigue encontrando sus cosas (alias).
        if (gr !== "" && (root.normGroup(gr) === root.normGroup(q) || root.normGroup(gr).startsWith(q)))
            return 50;
        return -1;
    }

    function rawPoolForGroup(g) {
        const items = root.ensureBase();
        const nid = root.normGroup(g);
        if (nid === "recent" || nid === "recientes" || nid === "history") {
            const rec = root.recentList();
            const out = [];
            for (let r = 0; r < rec.length; r++) {
                const raw = root.findRaw(rec[r]);
                if (raw)
                    out.push(raw);
            }
            return out;
        }
        if (nid === "fav" || nid === "favorito" || nid === "favoritos" || nid === "star") {
            const favs = root.favoriteList();
            const out = [];
            for (let f = 0; f < favs.length; f++) {
                const raw = root.findRaw(favs[f]);
                if (raw)
                    out.push(raw);
            }
            return out;
        }
        if (nid === "")
            return items;
        return items.filter(it => root.normGroup(it.group) === nid);
    }

    // Sinónimos de consulta emitidos por el script (`#SYN`): escribir
    // "lol" también prueba "laugh"/"joy". La mejor variante gana.
    property var querySyn: ({})

    function escapeRegExp(s) {
        return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function expandQueries(rest) {
        const toks = rest.split(/\s+/).filter(t => t !== "");
        let variants = [rest];
        for (let i = 0; i < toks.length; i++) {
            const syn = root.querySyn[toks[i]];
            if (!syn)
                continue;
            const re = new RegExp("\\b" + root.escapeRegExp(toks[i]) + "\\b", "g");
            const base = variants.slice();
            for (let v = 0; v < base.length && variants.length < 10; v++)
                for (let s = 0; s < syn.length && variants.length < 10; s++) {
                    const nv = base[v].replace(re, syn[s]);
                    if (variants.indexOf(nv) < 0)
                        variants.push(nv);
                }
        }
        return variants;
    }

    // Búsqueda cruda rankeada (sin envolver para pintar). Sin tope:
    // devuelve TODAS las coincidencias (limit solo si se pide explícito).
    function searchRaw(query, limit) {
        const items = root.ensureBase();
        const max = limit || 0;
        const qt = String(query || "").trim().toLowerCase();
        const gm = qt.match(/(?:group|g):([a-záéíóú]+)/);
        let pool = items;
        let rest = qt;
        if (gm) {
            pool = root.rawPoolForGroup(gm[1]);
            rest = qt.replace(gm[0], "").trim();
        }
        if (rest === "")
            return max > 0 ? pool.slice(0, max) : pool.slice();
        const recents = root.recentList();
        const favs = root.favoriteList();
        const variants = root.expandQueries(rest);
        const scored = [];
        for (let i = 0; i < pool.length; i++) {
            let s = -1;
            for (let qv = 0; qv < variants.length; qv++) {
                const qs = root.scoreRaw(pool[i], variants[qv]);
                if (qs > s)
                    s = qs;
            }
            if (s < 0)
                continue;
            let boost = 0;
            if (favs.indexOf(pool[i].ch) >= 0)
                boost += 6;
            const ri = recents.indexOf(pool[i].ch);
            if (ri >= 0)
                boost += Math.max(1, 5 - Math.floor(ri / 3));
            // Lo tuyo antes que lo generado a igual score.
            boost += (1 - Math.min(1, pool[i].src)) * 0.5;
            scored.push({ it: pool[i], score: s + boost });
        }
        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            const al = (a.it.name || "").length - (b.it.name || "").length;
            if (al !== 0)
                return al;
            return String(a.it.name || "").localeCompare(String(b.it.name || ""));
        });
        return (max > 0 ? scored.slice(0, max) : scored).map(e => e.it);
    }

    // Item listo para el delegate genérico de AppLauncher.
    function toResultItem(raw, catLabel) {
        const grp = (raw && raw.group) || "";
        const kw = (raw && raw.kw) || "";
        const fav = root.isFavorite(raw.ch);
        const rec = root.recentList().indexOf(raw.ch) >= 0;
        let badge = "";
        if (fav)
            badge += "★ ";
        else if (rec)
            badge += "↻ ";
        return {
            kind: "emoji", title: raw.ch + "  " + raw.name,
            sub: badge + kw + (grp !== "" ? " · " + root.groupLabel(grp) : ""),
            iconName: "", appIcon: "", ch: raw.ch, imagePath: "",
            cat: catLabel, name: raw.name || "", keywords: kw, group: grp,
            codepoints: root.codepoints(raw.ch),
            isFavorite: fav, isRecent: rec
        };
    }

    // Vía única para AppLauncher.results: sin query muestra recientes
    // primero y luego TODO lo generado (caras delante, símbolos al final:
    // ya viene ordenado del script); con query, ranking + grupo.
    // Sin tope: el buscador permite todos los emojis.
    // Memoización behavior-preserving: la misma query con la misma
    // revision/idioma (vía catLabel traducido) devuelve el mismo array
    // sin reconstruir miles de wrappers. Se invalida con revision y se
    // acota a 50 entradas. La caché vive en CAMPOS de un objeto JS que
    // solo se mutan (reasignar notificaría y estas funciones se llaman
    // desde bindings: ver SystemMenuRegistry._memo).
    property var _qmemo: ({ rev: -1, map: ({}), keys: [] })

    function queryItems(query, catLabel, limit) {
        const rev = root.revision;
        if (rev !== root._qmemo.rev) {
            root._qmemo.rev = rev;
            root._qmemo.map = {};
            root._qmemo.keys = [];
        }
        const max = limit || 0;
        const qt = String(query || "").trim();
        const key = rev + "\n" + (catLabel || "") + "\n" + qt + "\n" + max;
        const hit = root._qmemo.map[key];
        if (hit)
            return hit;
        const out = root.queryItemsFresh(qt, catLabel || "", max);
        root._qmemo.map[key] = out;
        root._qmemo.keys.push(key);
        if (root._qmemo.keys.length > 50)
            delete root._qmemo.map[root._qmemo.keys.shift()];
        return out;
    }

    function queryItemsFresh(qt, catLabel, max) {
        if (qt === "") {
            const out = [];
            const seen = {};
            const rec = root.recentList();
            for (let r = 0; r < rec.length; r++) {
                const raw = root.findRaw(rec[r]);
                if (raw && !seen[raw.ch]) {
                    seen[raw.ch] = true;
                    out.push(root.toResultItem(raw, catLabel));
                }
            }
            const items = root.ensureBase();
            for (let i = 0; i < items.length; i++) {
                if (seen[items[i].ch])
                    continue;
                seen[items[i].ch] = true;
                out.push(root.toResultItem(items[i], catLabel));
                if (max > 0 && out.length >= max)
                    break;
            }
            return out;
        }
        return root.searchRaw(qt, max).map(raw => root.toResultItem(raw, catLabel));
    }
}
