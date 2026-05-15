-- configs/rules_windows/someFixes.lua
hl.window_rule({
    name = "noblur-anonymous",
    match = { class = "^$", title = "^$" },
    no_blur = true,
})

hl.window_rule({
    name = "nofocus-xwayland-ghost",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "suppress-max-non-firefox",
    match = { class = "negative:firefox" },
    suppress_event = "maximize",
})
