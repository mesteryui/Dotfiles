// --- Items (predicados puros sobre items de resultados) ---
// ¿El item tiene preview con imagen diferida (clipboard / audio / video / pdf)?
// ¿Previsualiza texto? ¿Es texto del portapapeles (preview propia de cuerpo)?
// Sin estado ni dependencias QML: la usan AppLauncher y PreviewPanel.

.pragma library

function hasLivePreview(cur) {
    if (!cur)
        return false;
    if (cur.kind === "clip" && cur.isImage)
        return true;
    if (cur.kind === "file" && (cur.media === "audio" || cur.media === "video" || cur.media === "pdf"))
        return true;
    return false;
}

function hasTextPreview(cur) {
    return cur && cur.kind === "file" && cur.media === "text";
}

function isClipText(cur) {
    return cur && cur.kind === "clip" && !cur.isImage;
}
