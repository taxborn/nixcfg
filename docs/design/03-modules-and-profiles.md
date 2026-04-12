# 03 - modules and profiles

## the enable/mkIf pattern

Every module in `modules/nixos/` and `modules/home/` follows the same
shape:

```nix
{ config, lib, pkgs, ... }:
{
  options.myNixOS.services.foo = {
    enable = lib.mkEnableOption "foo service";
    # other options...
  };

  config = lib.mkIf config.myNixOS.services.foo.enable {
    # actual configuration
  };
}
```

This means every module can be imported unconditionally from a parent
aggregator (`modules/nixos/services/default.nix`) and only activates
when a host opts in. Hosts become a flat list of `myNixOS.services.foo.enable = true;`
declarations, which is easy to diff and review.

The tradeoff: option declarations add boilerplate for modules that are
only ever enabled on one host. I accept this because it keeps the
import graph uniform. If a module is truly single-use, it still reads
the same way as a shared one, and promoting it later is free.

## auto-wiring

A few modules pull in their dependencies automatically:

- `myHome.desktop.hyprland.enable = true` auto-enables rofi, gnome-keyring,
  mako, waybar, hypridle. The hyprland module treats itself as a
  "desktop shell" bundle rather than just the compositor.
- The amd GPU module sets up mesa/vulkan packages so hosts do not need
  to duplicate `hardware.graphics.extraPackages`.

The rule: if enabling X without Y always breaks, Y should be implied by
X. Anything optional stays a separate enable flag.

## profile hierarchy

Profiles aggregate enable flags into named bundles so hosts stay short.

### NixOS profiles (`modules/nixos/profiles/`)
- `audio` - pipewire stack
- `bluetooth` - bluez + blueman
- `btrfs` - scrub + compression defaults
- `graphical-boot` - plymouth
- `performance` - CPU governor, zram
- `swap` - swap file layout

Hosts cherry-pick these. There is no `myNixOS.profiles.workstation`
that enables all of them because the set is small enough that explicit
is clearer.

### home-manager profiles (`homes/profiles/`)
- `default.nix` - base: shell, dev tools, git, gpg, tmux, yubikey
- `workstation.nix` - GUI layer: hyprland, browser, media, bitwarden
- `server.nix` - headless, minimal on top of default

Carbon, argon, and helium-01 use `profile-server`. Uranium and tungsten
use `profile-workstation`. The split exists so server hosts do not
build closures for firefox and hyprland just to get a shell. Keeping
the base profile lean is the whole point of the split; new GUI stuff
goes in `workstation.nix`, not `default.nix`.

## user-scoped modules

`modules/home/taxborn/` holds things that only make sense for my user
(firefox config with my bookmarks, git signing key, etc.). If a second human ever uses one of these 
hosts, their modules live in a sibling directory under `modules/home/<name>/` without touching mine.
