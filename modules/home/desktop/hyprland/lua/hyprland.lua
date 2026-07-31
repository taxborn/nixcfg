require("keybinds")
require("monitors")
require("decorations")
require("animations")
require("rules")

local terminal = "ghostty"

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal)
    hl.exec_cmd("waybar")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
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
