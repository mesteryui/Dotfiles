-- configs/devices.lua
hl.config({
    input = {
        kb_layout = "es",
        kb_variant = ",esperanto",
        kb_options = "esperanto:qwerty,grp:alt_shift_toggle",
        follow_mouse = 1,
        sensitivity = 0,
        natural_scroll = true, -- 1 in conf
        touchpad = {
            tap_to_click = true, -- 11? maybe true
            middle_button_emulation = true,
            disable_while_typing = true,
        },
      },
  })

hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})
