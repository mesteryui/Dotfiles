-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action
return {
enable_wayland = true,
front_end = "OpenGL",
automatically_reload_config = true,
    window_background_opacity = 0.90,
    font = wezterm.font_with_fallback({ 
    {family="JetBrainsMono Nerd Font", harfbuzz_features={"calt=1", "clig=1", "liga=1"}},
    "Noto Color Emoji",
    "Symbols Nerd Font Mono"
    }),
    font_size = 10.5,
    line_height = 1.2,
    initial_rows = 23,
    initial_cols = 106,
    color_scheme = "Catppuccin Mocha", 
    use_fancy_tab_bar = false,
    enable_tab_bar = true,
    tab_bar_at_bottom = true,
    hide_tab_bar_if_only_one_tab = true,
    warn_about_missing_glyphs = false,
    default_cursor_style = 'SteadyBar',
    keys = {
    {key = "d",mods = "CTRL",action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain"}},
    -- Dividir el panel verticalmente (Ctrl + Shift + V)
    {key = "v", mods = "ALT",action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" },},
 {key = "t", mods = "ALT",action = wezterm.action.SpawnTab "CurrentPaneDomain",},
	{key="q", mods="CTRL", action=act.CloseCurrentTab{confirm = true}},
        {key="1", mods="CTRL|SUPER", action=act{ActivateTab=0}},
        {key="2", mods="CTRL|SUPER", action=act{ActivateTab=1}},
        {key="3", mods="CTRL|SUPER", action=act{ActivateTab=2}},
        {key="4", mods="CTRL|SUPER", action=act{ActivateTab=3}},
        {key="5", mods="CTRL|SUPER", action=act{ActivateTab=4}},
        {key="6", mods="CTRL|SUPER", action=act{ActivateTab=5}},
        {key="7", mods="CTRL|SUPER", action=act{ActivateTab=6}},
        {key="8", mods="CTRL|SUPER", action=act{ActivateTab=7}},
        {key="9", mods="CTRL|SUPER", action=act{ActivateTab=8}},
        {key="0", mods="CTRL|SUPER", action=act{ActivateTab=9}},
}
}
