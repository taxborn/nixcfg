hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    -- Keeps XWayland drag-and-drop working: the empty, untitled window a drag
    -- puts up must not take focus. The match is narrow on purpose, since
    -- no_focus on every classless window would be a much bigger rule.
    name     = "fix-xwayland-drags",
    match    = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name      = "discord-special-workspace",
    match     = { class = "vesktop" },
    workspace = "special:discord",
})
