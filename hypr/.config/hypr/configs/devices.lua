-- configs/devices.lua
hl.config({
    input = {
        kb_layout = "es",
        kb_variant = ",esperanto",
        kb_options = "esperanto:qwerty,grp:alt_shift_toggle",
        follow_mouse = 1,
        sensitivity = 0,
        repeat_rate = 40,
        natural_scroll = true, -- 1 in conf
        touchpad = {
            tap_to_click = true, -- 11? maybe true
            middle_button_emulation = false,
            disable_while_typing = true,
            clickfinger_behavior = true,
            tap_and_drag = true,
        },
        accel_profile = "flat",
      },
  })
