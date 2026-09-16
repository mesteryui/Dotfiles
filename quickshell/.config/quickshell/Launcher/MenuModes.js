// --- MenuModes (base común de menús) ---
// Cada menú es distinto (apps, sistema, archivos, web, emoji, calc,
// clipboard) pero comparte la misma base: { modeId, selectorChar, previewMode }.
//   selectorChar  → carácter selector que fuerza el menú al teclearlo
//                   ("" = menú por defecto, sin prefijo).
//   previewMode   → "always" (clip: texto completo/imagen),
//                   "conditional" (files/system: solo si el item trae
//                   imagen o texto previsualizable), "never" (resto).
//
// needsPreview(modeId, item) decide si el panel lateral de preview es
// imprescindible para el item actual:
//   clip   → siempre (ver texto completo o imagen).
//   files  → solo image/text/pdf/audio/video (miniatura o texto).
//   system → solo si trae imagePath (ej. temas fastfetch con preview).
//   resto  → nunca.

.pragma library

function defs() {
    return [
        { modeId: "todo", selectorChar: "", previewMode: "never" },
        { modeId: "system", selectorChar: ">", previewMode: "conditional" },
        { modeId: "files", selectorChar: "/", previewMode: "conditional" },
        { modeId: "web", selectorChar: "@", previewMode: "never" },
        { modeId: "emoji", selectorChar: ".", previewMode: "never" },
        { modeId: "calc", selectorChar: "=", previewMode: "never" },
        { modeId: "clip", selectorChar: ":", previewMode: "always" }
    ];
}

function prefixOf(modeId) {
    var d = defs();
    for (var i = 0; i < d.length; i++)
        if (d[i].modeId === modeId)
            return d[i].selectorChar;
    return "";
}

function modeForPrefix(text) {
    var d = defs();
    for (var i = 0; i < d.length; i++) {
        var c = d[i].selectorChar;
        if (c !== "" && text.length > 0 && text.indexOf(c) === 0)
            return d[i].modeId;
    }
    return "";
}

function supportsPreview(modeId) {
    var d = defs();
    for (var i = 0; i < d.length; i++)
        if (d[i].modeId === modeId)
            return d[i].previewMode !== "never";
    return false;
}

// ¿El item actual necesita preview? Solo se usa donde es imprescindible.
function needsPreview(modeId, item) {
    if (!item)
        return false;
    if (modeId === "clip" && item.kind === "clip")
        return true;
    if (modeId === "files" && item.kind === "file") {
        return item.media === "image" || item.media === "text" || item.media === "pdf"
            || item.media === "audio" || item.media === "video";
    }
    if (modeId === "system" && item.kind === "system") {
        return (item.imagePath || "") !== "";
    }
    return false;
}
