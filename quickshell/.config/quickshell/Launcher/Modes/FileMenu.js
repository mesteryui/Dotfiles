// --- FileMenu (lógica pura del modo archivos, en Modes/) ---
// Clasificación por extensión, comando fd, mapeo snapshot→items,
// ordenado y comando de apertura. Sin estado ni singletons:
// LauncherFileSearch/AppLauncher aportan snapshot/query/textos y los
// servicios (FuzzySearch, xdg-open).
//
// NOTA: no importa ShellUtils.js porque el motor QML no permite `import`
// entre .js (ni con .pragma library ni sin él). Las dos funciones de
// abajo son copia literal de Launcher/Base/ShellUtils.js: si cambian allí,
// cambiar aquí.

function shellEscape(s) {
    return String(s).replace(/'/g, "'\\''");
}

function fileUrl(path) {
    const p = String(path ?? "");
    if (p === "")
        return "";
    return "file://" + p.split("/").map(encodeURIComponent).join("/");
}

const fileExcludes = [
    ".git", ".cache", ".local", ".var", ".cargo", ".npm", ".bun",
    ".gradle", ".pub-cache", ".dart-tool", ".mozilla", ".floorp",
    ".thunderbird", ".wine", ".steam", ".stremio-server", ".bitmonero",
    ".vscode-oss", ".vscode-oss-shared", ".renpy", ".vm-space", ".java",
    "node_modules", "__pycache__", ".venv"
];

function fileMedia(path, isDir) {
    if (isDir)
        return "other";
    if (/\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(path))
        return "image";
    if (/\.(mp3|flac|m4a|aac|ogg|opus|wav|wma|aiff|ape)$/i.test(path))
        return "audio";
    if (/\.(mp4|m4v|mkv|webm|mov|avi|3gp|ts|mts|flv)$/i.test(path))
        return "video";
    if (/\.pdf$/i.test(path))
        return "pdf";
    if (/\.(txt|md|markdown|json|jsonc|qml|js|ts|py|sh|lua|rs|toml|yaml|yml|ini|conf|cfg|log|csv|css|html|xml|vim|fish|c|h|cpp|hpp|go|java|nix|rasi|desktop)$/i.test(path))
        return "text";
    return "other";
}

function fdCommand(home, query) {
    // Solo ficheros dentro de $HOME (o sus subrutas): sin directorios.
    const cmd = ["fd", "--type", "f"];
    for (let i = 0; i < fileExcludes.length; i++)
        cmd.push("--exclude", fileExcludes[i]);
    if (query === "") {
        // Sin patrón `fd` tomaría $HOME como patrón y no devolvería nada.
        cmd.push("--max-results", "200", ".", home);
    } else {
        // Con query: todo incluido ocultos, en literal. El "--" evita que
        // una query como "-e" se interprete como flag (flag injection).
        cmd.push("--hidden", "--fixed-strings", "--max-results", "100", "--", query, home);
    }
    return cmd;
}

// snapshot [{path, name, isDir}] → items del launcher (sin filtrar).
function mapSnapshot(snapshot, cat) {
    const out = [];
    for (let i = 0; i < snapshot.length; i++) {
        const e = snapshot[i];
        const media = fileMedia(e.path, e.isDir);
        let icon = "description";
        if (media === "image")
            icon = "image";
        else if (media === "audio")
            icon = "audio_file";
        else if (media === "video")
            icon = "video_file";
        else if (media === "pdf")
            icon = "picture_as_pdf";
        else if (media === "text")
            icon = "article";
        else if (e.isDir)
            icon = "folder";
        out.push({ kind: "file", title: e.name, sub: e.path,
                   iconName: icon,
                   appIcon: "", ch: "", imagePath: media === "image" ? fileUrl(e.path) : "",
                   cat: cat, path: e.path, media: media });
    }
    return out;
}

// El nombre manda: lo que empieza por lo tecleado va primero.
// Comparación normalizada (minúsculas + sin acentos) para que
// "config" también anteponga "Configuración".
function normLower(s) {
    let t = String(s || "").toLowerCase();
    try {
        if (t.normalize)
            t = t.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    } catch (e) {}
    return t.replace(/[áàäâ]/g, "a").replace(/[éèëê]/g, "e")
            .replace(/[íìïî]/g, "i").replace(/[óòöô]/g, "o")
            .replace(/[úùüû]/g, "u").replace(/ñ/g, "n").replace(/ç/g, "c");
}

function nameFirst(matches, q) {
    const queryLower = normLower(q);
    const first = [];
    const rest = [];
    for (let i = 0; i < matches.length; i++) {
        const t = normLower(matches[i].title || "");
        if (t.indexOf(queryLower) === 0)
            first.push(matches[i]);
        else
            rest.push(matches[i]);
    }
    return first.concat(rest);
}

// Orden base del listado: alfabético insensible a mayúsculas
// (se tolera isDir por robustez aunque fd ya no devuelva carpetas).
function sortSnapshot(out) {
    out.sort((a, b) => {
        if (a.isDir !== b.isDir)
            return a.isDir ? -1 : 1;
        const an = String(a.name).toLowerCase();
        const bn = String(b.name).toLowerCase();
        return an < bn ? -1 : an > bn ? 1 : 0;
    });
    return out;
}

// Comando sh -c para openPath: comprueba existencia, abre con xdg-open
// y avisa con notify-send si desapareció o no se pudo abrir.
function openCommand(path, title, missingMsg, failedMsg) {
    const p = shellEscape(path);
    const t = shellEscape(title);
    const m = shellEscape(missingMsg);
    const f = shellEscape(failedMsg);
    return "if [ -e '" + p + "' ]; then xdg-open '" + p + "' >/dev/null 2>&1 || notify-send '" + t + "' '" + f + "'; else notify-send '" + t + "' '" + m + "'; fi";
}
