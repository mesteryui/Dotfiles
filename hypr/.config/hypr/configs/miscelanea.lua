-- configs/miscelanea.lua
hl.config({
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
        enforce_permissions = false,
    },
    misc = {
        anr_missed_pings = 3,
        middle_click_paste = false,
        disable_hyprland_logo = true,
        initial_workspace_tracking = 0,
        disable_splash_rendering = false,
        disable_scale_notification = true,
        enable_swallow = true,
        swallow_regex = "(kitty|ghostty)",
        focus_on_activate = true,
        on_focus_under_fullscreen = 1,
        allow_session_lock_restore = true,
        key_press_enables_dpms = true,
        mouse_move_enables_dpms = true
    },
})
hl.config({binds = {hide_special_on_workspace_change = true}})
