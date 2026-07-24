-- configs/rules_windows/floating.lua
-- Reglas de comportamiento para ventanas flotantes (diálogos, modales, utilidades)

-- Aplicaciones y diálogos que deben flotar por defecto
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor)$" },
    { class = "^(blueberry.py|org.localsend.localsend_app)$" },
    { class = "^(galculator)$" },
    { class = "^(imv)$" },
    { class = "^(mpv|io.github.diegopvlk.Cine)$" },
    { title = "^(Winetricks.*|Protontricks.*)$" },
    { title = "^(Acerca.*|Watering)$" },
}

for _, m in ipairs(floatApps) do
    hl.window_rule({ match = m, float = true })
end

-- Centrar y redimensionar aplicaciones multimedia flotantes específicas
hl.window_rule({
    match = { class = "^(mpv|io.github.diegopvlk.Cine)$" },
    center = true,
    size = { 900, 500 },
})

-- Dimensiones específicas para galculator
hl.window_rule({
    match = { class = "^(galculator)$" },
    size = { 100, 200 },
})

-- Coincidencias de diálogos y ventanas modales del sistema
local modalMatches = {
    { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" },
    { initial_title = "^(Open File)$" },
    { class = "^([Xx]dg-desktop-portal-gtk)$" },
    { title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
    { class = "^(.*dialog.*)$" },
    { title = "^(.*dialog.*)$" },
    { class = "^(hyprland-share-picker)$" },
}

for _, m in ipairs(modalMatches) do
    hl.window_rule({ match = m, float = true, center = true })
end

-- Regla genérica para etiquetas de ventanas flotantes customizadas
hl.window_rule({
    name = "tag-floating-window",
    match = { tag = "floating-window" },
    float = true,
    center = true,
    size = { 900, 800 },
})

-- Asignación de tag a imv para que herede la regla de floating-window
hl.window_rule({
    match = { class = "^(imv)$" },
    tag = "+floating-window",
})
