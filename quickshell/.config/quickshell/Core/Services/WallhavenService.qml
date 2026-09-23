// --- WallhavenService (Singleton) ---
// Búsqueda y descarga de fondos desde wallhaven.cc a la carpeta local de
// wallpapers (WallpaperService.wallpaperDir).
//
// Filtros como la web: texto, categorías (general/anime/people), pureza
// (sfw/sketchy, nsfw solo con apiKey), orden (relevancia, fecha, visitas,
// favoritos, toplist, aleatorio), dirección, rango del toplist y resolución
// mínima (atleast). La UI vive en Panels/Wallhaven/.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../Log.js" as Log

Singleton {
    id: root

    // ---- filtros (la UI los liga) ----
    property string query: ""
    property bool catGeneral: true
    property bool catAnime: true
    property bool catPeople: true
    property bool puritySfw: true
    property bool puritySketchy: false
    property bool purityNsfw: false
    // Clave opcional de https://wallhaven.cc/settings/account (solo para nsfw).
    property string apiKey: ""
    // relevance | date_added | views | favorites | toplist | random
    property string sorting: "date_added"
    property string order: "desc"
    // 1d | 3d | 1w | 1M | 3M | 6M | 1y (solo con sorting == "toplist")
    property string topRange: "1M"
    // Resolución mínima "1920x1080" (vacío = sin filtro).
    property string atleast: ""

    // ---- estado ----
    property int page: 1
    property int lastPage: 1
    property int total: 0
    property var results: []
    property bool loading: false
    // Código de error para traducir en la UI: "" | "http" | "invalid"
    // | "offline" | "download". Detalle libre (p. ej. código HTTP).
    property string errorCode: ""
    property string errorDetail: ""
    property string busyId: ""
    property var downloadedIds: []

    property var _xhr: null

    function _purity() {
        let p = (root.puritySfw ? "1" : "0") + (root.puritySketchy ? "1" : "0");
        p += (root.purityNsfw && root.apiKey !== "" ? "1" : "0");
        return p === "000" ? "100" : p;
    }

    function _categories() {
        return (root.catGeneral ? "1" : "0") + (root.catAnime ? "1" : "0") + (root.catPeople ? "1" : "0");
    }

    function searchUrl(targetPage) {
        let url = "https://wallhaven.cc/api/v1/search?q=" + encodeURIComponent(root.query.trim());
        url += "&categories=" + root._categories();
        url += "&purity=" + root._purity();
        url += "&sorting=" + root.sorting + "&order=" + root.order;
        if (root.sorting === "toplist")
            url += "&topRange=" + root.topRange;
        if (root.atleast.trim() !== "")
            url += "&atleast=" + encodeURIComponent(root.atleast.trim());
        url += "&page=" + targetPage;
        if (root.apiKey !== "")
            url += "&apikey=" + encodeURIComponent(root.apiKey);
        return url;
    }

    function search(resetPage) {
        if (resetPage ?? true)
            root.page = 1;
        if (root._xhr) {
            const prev = root._xhr;
            root._xhr = null;
            prev.abort();
        }
        root.loading = true;
        root.errorCode = "";
        root.errorDetail = "";
        const xhr = new XMLHttpRequest();
        root._xhr = xhr;
        xhr.timeout = 15000;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr !== root._xhr)
                return;
            root._xhr = null;
            root.loading = false;
            if (xhr.status !== 200) {
                // status 0 = sin red (DNS/caída), no un HTTP real: marcar
                // offline sin spamear el log con "HTTP 0".
                if (xhr.status === 0) {
                    root.errorCode = "offline";
                    root.errorDetail = "";
                    Log.warn("[Wallhaven] sin conexión (búsqueda pospuesta)");
                } else {
                    root.errorCode = "http";
                    root.errorDetail = String(xhr.status);
                    Log.error("[Wallhaven] búsqueda falló: HTTP " + xhr.status);
                }
                return;
            }
            try {
                const json = JSON.parse(xhr.responseText);
                const out = [];
                const data = json.data ?? [];
                for (let i = 0; i < data.length; i++) {
                    const w = data[i];
                    const ext = String(w.path ?? "").split(".").pop().toLowerCase().split("?")[0];
                    const bytes = Number(w.file_size ?? 0);
                    out.push({
                        id: String(w.id ?? ""),
                        resolution: w.resolution ?? "",
                        sizeLabel: bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(bytes / 1024)) + " KB",
                        category: w.category ?? "",
                        purity: w.purity ?? "",
                        views: w.views ?? 0,
                        favorites: w.favorites ?? 0,
                        pageUrl: w.short_url ?? w.url ?? "",
                        imageUrl: w.path ?? "",
                        thumb: (w.thumbs && w.thumbs.large) || "",
                        ext: ["jpg", "jpeg", "png", "webp"].indexOf(ext) >= 0 ? ext : "jpg"
                    });
                }
                root.results = out;
                root.lastPage = json.meta?.last_page ?? 1;
                root.total = json.meta?.total ?? out.length;
            } catch (e) {
                root.errorCode = "invalid";
                root.errorDetail = "";
                Log.error("[Wallhaven] respuesta inválida:", e);
            }
        };
        xhr.onerror = () => {
            if (xhr !== root._xhr)
                return;
            root._xhr = null;
            root.loading = false;
            root.errorCode = "offline";
            root.errorDetail = "";
            Log.warn("[Wallhaven] sin conexión (búsqueda pospuesta)");
        };
        xhr.ontimeout = () => {
            if (xhr !== root._xhr)
                return;
            root._xhr = null;
            root.loading = false;
            root.errorCode = "offline";
            root.errorDetail = "";
            Log.warn("[Wallhaven] tiempo de espera agotado (sin conexión?)");
        };
        xhr.open("GET", root.searchUrl(root.page));
        xhr.send();
    }

    // Reintento automático al recuperar red, solo si quedó pendiente
    // por offline y sin resultados (misma idea que WeatherService).
    Connections {
        target: NetworkService

        function onCurrentNetworkChanged() {
            if (NetworkService?.currentNetwork !== null && !root.loading && root.errorCode === "offline" && root.results.length === 0)
                root.search(true);
        }
    }

    function nextPage() {
        if (root.loading || root.page >= root.lastPage)
            return;
        root.page += 1;
        root.search(false);
    }

    function prevPage() {
        if (root.loading || root.page <= 1)
            return;
        root.page -= 1;
        root.search(false);
    }

    function isDownloaded(id) {
        if (root.downloadedIds.indexOf(id) >= 0)
            return true;
        // En disco de sesiones anteriores (downloadedIds es solo memoria).
        return root._hasDiskFile(id);
    }

    // ¿Existe ya wallhaven-<id>.<ext> en la carpeta de fondos? Lee el
    // FolderListModel de WallpaperService (reactivo: la UI se actualiza
    // sola al terminar de listar el directorio).
    function _hasDiskFile(id) {
        if (!id)
            return false;
        const list = WallpaperService.wallpaperList;
        const prefix = "wallhaven-" + id + ".";
        for (let i = 0; i < list.count; i++)
            if (String(list.get(i, "fileName") ?? "").startsWith(prefix))
                return true;
        return false;
    }

    // Nombre real en disco (por si la extensión difiere) o "".
    function diskFileFor(item) {
        if (!item || !item.id)
            return "";
        const list = WallpaperService.wallpaperList;
        const prefix = "wallhaven-" + item.id + ".";
        for (let i = 0; i < list.count; i++) {
            const name = String(list.get(i, "fileName") ?? "");
            if (name.startsWith(prefix))
                return name;
        }
        return "";
    }

    // ---- descarga (una a la vez, con cola) ----
    property var _queue: []
    property string _pendingApply: ""

    function fileNameFor(item) {
        return "wallhaven-" + item.id + "." + item.ext;
    }

    // Aplica directo desde disco si ya está descargado (incluso de
    // sesiones anteriores); si no, descarga y aplica al terminar.
    function applyNow(item) {
        if (!item || !item.id)
            return;
        const disk = root.diskFileFor(item);
        if (disk !== "")
            WallpaperService.apply(disk);
        else if (root.downloadedIds.indexOf(item.id) >= 0)
            WallpaperService.apply(root.fileNameFor(item));
        else
            root.download(item, true);
    }

    function download(item, applyAfter) {
        if (!item || !item.imageUrl || root.busyId === item.id)
            return;
        for (let i = 0; i < root._queue.length; i++)
            if (root._queue[i].item.id === item.id)
                return;
        root._queue.push({
            item: item,
            applyAfter: applyAfter ?? false
        });
        root._pumpQueue();
    }

    function _pumpQueue() {
        if (root.busyId !== "" || root._queue.length === 0)
            return;
        const job = root._queue.shift();
        const dest = WallpaperService.wallpaperDir + "/" + root.fileNameFor(job.item);
        root._pendingApply = job.applyAfter ? root.fileNameFor(job.item) : "";
        root.busyId = job.item.id;
        // --create-dirs crea la carpeta si no existe.
        dlProc.command = ["curl", "-sSL", "--create-dirs", "-o", dest, job.item.imageUrl];
        dlProc.running = true;
    }

    Process {
        id: dlProc

        onExited: (exitCode, exitStatus) => {
            const doneId = root.busyId;
            root.busyId = "";
            if (exitCode === 0) {
                if (root.downloadedIds.indexOf(doneId) < 0)
                    root.downloadedIds = root.downloadedIds.concat([doneId]);
                if (root._pendingApply !== "") {
                    WallpaperService.apply(root._pendingApply);
                    root._pendingApply = "";
                }
            } else {
                Log.error("[Wallhaven] descarga falló id=" + doneId + " code=" + exitCode);
                root.errorCode = "download";
                root.errorDetail = String(exitCode);
            }
            root._pumpQueue();
        }
    }
}
