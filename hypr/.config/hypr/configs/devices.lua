-- configs/devices.lua
hl.config({
    input = {
        kb_layout = "es",
        kb_variant = ",esperanto",
        kb_options = "esperanto:qwerty,grp:alt_shift_toggle",
        follow_mouse = 1,
        repeat_delay = 250,
        repeat_rate = 35,
        off_window_axis_events = 2,
        touchpad = {
            tap_to_click = true, -- 11? maybe true
            middle_button_emulation = false,
            disable_while_typing = true,
            clickfinger_behavior = true,
            tap_and_drag = true,
            natural_scroll = true,
            scroll_factor = 1
        },
       -- accel_profile = "flat",
      },
  })
