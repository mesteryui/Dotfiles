-- configs/rules_windows/btop.lua
hl.window_rule({
    name = "btop-floating",
    match = { class = "^(local.btopfloat)$" },
    float = true,
    size = "(monitor_w * 0.3) (monitor_h * 0.6)",
    center = true,
})
