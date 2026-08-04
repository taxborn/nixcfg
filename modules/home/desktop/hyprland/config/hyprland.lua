require("keybinds")
require("monitors")
require("decorations")
require("animations")
require("rules")

local terminal = "ghostty"

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal)
    hl.exec_cmd("waybar & hyprpaper")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("[workspace special:terminal silent] ghostty -e tmux new-session -A -s main")
    hl.exec_cmd("[workspace special:discord silent] vesktop")
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    input = {
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.window_rule({
    name      = "discord-special-workspace",
    match     = { class = "vesktop" },
    workspace = "special:discord",
})
