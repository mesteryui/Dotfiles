// DdcUtils.js — helpers puros (sin dependencias QML) para Brightness.
// - parseDetect: salida de `ddcutil detect --brief` → [{connector, busNum}]
// - parseBacklightList: `basename|readlink` por línea → [{device, drm}]
// - parseVcpBrief: `ddcutil getvcp 10 --brief` ("VCP 10 C <cur> <max>")
// - parseSetValue: sintaxis estilo brightnessctl ("0.5", "+0.1", "50%"...)
// Todo con guardas: lo que no parsea se ignota/devuelve null, nunca throw.

function parseDetect(text) {
    const out = [];
    const blocks = String(text ?? "").split("\n\n");
    for (let i = 0; i < blocks.length; i++) {
        const b = blocks[i].trim();
        if (b === "" || !b.startsWith("Display "))
            continue;
        const busM = b.match(/I2C bus:\s*\/dev\/i2c-(\d+)/);
        const drmM = b.match(/DRM connector:\s*(\S+)/);
        // Bloque incompleto (p. ej. monitor sin DRM expuesto): se salta
        // en vez de romper el regex con null.
        if (!busM || !drmM)
            continue;
        out.push({
            busNum: busM[1],
            // "card1-HDMI-A-1" → "HDMI-A-1" (nombre que usa Hyprland/Qt).
            connector: drmM[1].replace(/^card\d+-/, "")
        });
    }
    return out;
}

function parseBacklightList(text) {
    const out = [];
    const lines = String(text ?? "").split("\n");
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line === "")
            continue;
        const sep = line.indexOf("|");
        if (sep < 0)
            continue;
        const device = line.slice(0, sep).trim();
        const target = line.slice(sep + 1);
        if (device === "")
            continue;
        // ".../drm/card1/card1-eDP-1/amdgpu_bl1" → "eDP-1".
        const m = target.match(/card\d+-([^/]+)/);
        out.push({
            device: device,
            drm: m ? m[1] : ""
        });
    }
    return out;
}

function parseVcpBrief(text) {
    const parts = String(text ?? "").trim().split(/\s+/);
    if (parts.length < 5)
        return null;
    const cur = parseInt(parts[3]);
    const max = parseInt(parts[4]);
    if (isNaN(cur) || isNaN(max) || max <= 0)
        return null;
    return {
        current: cur,
        max: max
    };
}

// Devuelve {ok:true, value} con valor absoluto 0..1, o {ok:false, error}.
// Acepta: "0.5" | "+0.1" | "0.1-" | "50%" | "+10%" | "10%-" (relativos al actual).
function parseSetValue(raw, current) {
    const value = String(raw ?? "").trim();
    if (value === "")
        return { ok: false, error: "empty value" };
    let target = NaN;
    if (value.endsWith("%-")) {
        const p = parseFloat(value.slice(0, -2));
        if (!isNaN(p))
            target = current - p / 100;
    } else if (value.startsWith("+") && value.endsWith("%")) {
        const p = parseFloat(value.slice(1, -1));
        if (!isNaN(p))
            target = current + p / 100;
    } else if (value.endsWith("%")) {
        const p = parseFloat(value.slice(0, -1));
        if (!isNaN(p))
            target = p / 100;
    } else if (value.startsWith("+")) {
        const d = parseFloat(value.slice(1));
        if (!isNaN(d))
            target = current + d;
    } else if (value.endsWith("-")) {
        const d = parseFloat(value.slice(0, -1));
        if (!isNaN(d))
            target = current - d;
    } else {
        const a = parseFloat(value);
        if (!isNaN(a))
            target = a;
    }
    if (isNaN(target))
        return { ok: false, error: "invalid format (use 0.5, +0.1, 0.1-, 50%, +10%, 10%-)" };
    return { ok: true, value: target };
}
