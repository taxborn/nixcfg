hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper & blueman-applet")
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
