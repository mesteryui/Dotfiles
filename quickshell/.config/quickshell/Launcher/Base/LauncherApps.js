// --- LauncherApps (helpers puros del modo aplicaciones) ---
// Orden, dedup y fijadas del modelo de .desktop. Sin estado ni
// singletons: AppLauncher aporta la lista y los pins.
// (Extraído de AppLauncher.qml para partir sus ~1400 líneas.)

.pragma library

function alphaSort(list) {
    return [...list].sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
}

// Deduplica .desktop duplicados (ej. "Aplicaciones web" sale dos veces:
// webapp-manager.desktop y kde4/webapp-manager.desktop, mismo Exec y
// mismo nombre). Quickshell filtra Hidden/NoDisplay pero no
// OnlyShowIn/NotShowIn, así que ambas variantes llegan aquí.
// Clave = línea de comando normalizada (+ nombre como desempate);
// ante choque gana la canónica (id sin "kde4", más corto).
function appDedupKey(e) {
    let cmd = "";
    if (e && e.command && typeof e.command.length === "number" && e.command.length > 0) {
        const parts = [];
        for (let i = 0; i < e.command.length; i++)
            parts.push(String(e.command[i]));
        cmd = parts.join(" ").trim().toLowerCase();
    } else if (e && e.execString) {
        cmd = String(e.execString).trim().toLowerCase();
    }
    const nm = String((e && e.name) || "").trim().toLowerCase();
    if (cmd !== "")
        return "c:" + cmd + "|n:" + nm;
    return "n:" + nm + "|id:" + String((e && e.id) || "");
}

function preferApp(a, b) {
    // true = quedarse con b en vez de a.
    const aid = String(a.id || "");
    const bid = String(b.id || "");
    const aKde = aid.toLowerCase().indexOf("kde4") >= 0;
    const bKde = bid.toLowerCase().indexOf("kde4") >= 0;
    if (aKde !== bKde)
        return bKde === false;
    if (bid.length !== aid.length)
        return bid.length < aid.length;
    return false;
}

function uniqueApps(list) {
    const seen = {};
    const out = [];
    for (let i = 0; i < list.length; i++) {
        const e = list[i];
        if (!e || e.noDisplay === true)
            continue;
        const k = appDedupKey(e);
        if (seen[k] === undefined) {
            seen[k] = out.length;
            out.push(e);
        } else if (preferApp(out[seen[k]], e)) {
            out[seen[k]] = e;
        }
    }
    return out;
}

// Foto plana de un DesktopEntry para guardar en modelos QML.
// Los DesktopEntry son QObjects vivos de Quickshell: si se guardan tal
// cual en un ScriptModel y los .desktop se reescanean en background, el
// objeto puede destruirse mientras el DelegateModel lo lee
// (QMetaProperty::read sobre objeto muerto -> SIGSEGV en setModel al
// teclear). El snapshot solo copia strings/arrays; la ejecución se
// resuelve contra el entry vivo por id en el momento de activar.
function snapshotEntry(e) {
    let cmd = [];
    if (e && e.command && typeof e.command.length === "number") {
        for (let i = 0; i < e.command.length; i++)
            cmd.push(String(e.command[i]));
    }
    return {
        isDesktopApp: true,
        id: String((e && e.id) || ""),
        name: String((e && e.name) || ""),
        comment: String((e && e.comment) || ""),
        icon: String((e && e.icon) || ""),
        command: cmd,
        workingDirectory: String((e && e.workingDirectory) || ""),
        runInTerminal: (e && e.runInTerminal) === true,
        execString: String((e && e.execString) || "")
    };
}

function pinFirst(pool, pins) {
    if (pins.length === 0)
        return pool;
    const byId = {};
    for (let i = 0; i < pool.length; i++)
        byId[pool[i].id] = pool[i];
    const head = [];
    for (let k = 0; k < pins.length; k++)
        if (byId[pins[k]])
            head.push(byId[pins[k]]);
    const tail = [];
    for (let j = 0; j < pool.length; j++)
        if (pins.indexOf(pool[j].id) < 0)
            tail.push(pool[j]);
    // Fijadas también en alfabético: la lista siempre empieza ordenada.
    return alphaSort(head).concat(tail);
}
