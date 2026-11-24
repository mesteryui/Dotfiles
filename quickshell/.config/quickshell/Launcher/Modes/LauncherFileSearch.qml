// --- LauncherFileSearch: búsqueda de archivos vía shinro-backend ---
// Dispara la consulta al backend (FilesService vía socket Unix) cuando
// cambia query o active. Mantiene un snapshot propio de items ya
// filtrados para que AppLauncher no tenga que hacer fuzzy search en el
// hilo UI ni reconstruir delegados en cada tecla.
// El backend excluye automáticamente directorios ocultos (.git, .cache,
// .config, .local, .wine...), rutas de caché/dependencias y enlaces
// simbólicos (evita duplicados).
pragma ComponentBehavior: Bound

import qs.Core.Services as Services
import "FileMenu.js" as FileMenu
import QtQuick
import Quickshell

QtObject {
    id: root

    property string query: ""
    property bool active: false

    // Snapshot de items ya filtrados y listos para mostrar en el launcher.
    // Se reconstruye cuando llegan resultados del backend o cambia la query.
    property var snapshot: []
    property bool failed: false
    property string failReason: ""

    // Escuchar resultsReady (se emite una vez cuando el backend termina de
    // llenar FilesService.results), en lugar de onCountChanged (que se
    // dispara por cada append individual).
    Component.onCompleted: {
        Services.FilesService.resultsReady.connect(root._onResultsReady);
        Services.FilesService.errorChanged.connect(root._onServiceError);
    }

    Component.onDestruction: {
        Services.FilesService.resultsReady.disconnect(root._onResultsReady);
        Services.FilesService.errorChanged.disconnect(root._onServiceError);
    }

    function _onResultsReady(query) {
        if (root.active && query === root.query) {
            root.failed = false;
            root.failReason = "";
            watchdogTimer.stop();
            root._buildSnapshot();
        }
    }

    // El servicio avisa cuando el backend no está disponible o no responde.
    // Mostrar el fallo en vez de una lista vacía silenciosa.
    function _onServiceError() {
        const err = Services.FilesService.error;
        if (!err) {
            root.failed = false;
            root.failReason = "";
            return;
        }
        root.failed = true;
        root.failReason = String(err);
        watchdogTimer.stop();
        if (err === "disconnected" || err === "socket")
            root.snapshot = [];
    }

    function refresh() {
        const home = Quickshell.env("HOME");
        if (!home) {
            root.failed = true;
            root.failReason = "home";
            root.snapshot = [];
            watchdogTimer.stop();
            return;
        }
        // Resetear fallo previo: cada nueva búsqueda parte limpia.
        root.failed = false;
        root.failReason = "";
        watchdogTimer.restart();
        // Envolver en variable para que QML no interprete la llamada como
        // asignación de propiedad.
        var _ = Services.FilesService.search(root.query, 200);
    }

    property Timer debounceTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: {
            if (root.active)
                root.refresh();
        }
    }

    property Timer watchdogTimer: Timer {
        interval: 15000
        repeat: false
        onTriggered: {
            if (root.active) {
                root.failed = true;
                root.failReason = "timeout";
            }
        }
    }

    onQueryChanged: {
        if (root.active)
            debounceTimer.restart();
        else
            debounceTimer.stop();
    }
    onActiveChanged: {
        if (root.active) {
            debounceTimer.restart();
        } else {
            debounceTimer.stop();
            watchdogTimer.stop();
            root.snapshot = [];
        }
    }

    // Construir snapshot filtrado desde FilesService.results.
    // Se llama solo cuando el backend responde para la query actual.
    function _buildSnapshot() {
        const res = Services.FilesService.results;
        const out = [];
        for (let i = 0; i < res.count; i++) {
            const e = res.get(i);
            // `kind` lo decide el backend por MIME (extensión + contenido).
            const media = FileMenu.mediaFor(e);
            out.push({
                         kind: "file",
                         title: e.name,
                         sub: e.path,
                         icon: FileMenu.iconFor(media, e.isDir),
                         appIcon: "",
                         ch: "",
                         imagePath: media === "image" ? FileMenu.fileUrl(e.path) : "",
                         path: e.path,
                         media: media,
                         mime: e.mime || ""
                     });
        }
        FileMenu.sortSnapshot(out);
        const q = root.query;
        if (q !== "") {
            const matches = Services.FuzzySearch.filterItemsMulti(q, out, it => [
            {
                text: it.title,
                weight: 1
            },
            {
                text: it.sub,
                weight: 0.25
            }
            ]);
            root.snapshot = FileMenu.nameFirst(matches, q);
        } else {
            root.snapshot = out;
        }
    }
}
