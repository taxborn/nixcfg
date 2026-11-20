# Niri and Noctalia

Uranium and Tungsten use Niri with Noctalia v5 from the pinned nixpkgs.
The NixOS Noctalia module installs the shell and enables its recommended
NetworkManager, Bluetooth, UPower and power profile services.
Tungsten keeps TuneD with its power-profiles compatibility service; Uranium
uses power-profiles-daemon.
Existing applications and their Catppuccin themes remain enabled. Desktop GTK,
Qt, icon and cursor themes are not configured.

## session

The existing getty autologin runs once per boot on tty1. The Fish login hook
executes `niri-session`, which imports the login environment and starts Niri's
systemd user service. The interactive-shell guard prevents recursion when
`niri-session` opens its own noninteractive login shell. Quitting Niri returns
to the login prompt. There is no greeter or UWSM.

Niri starts Noctalia with `spawn-at-startup`. Xwayland Satellite starts on demand
for X11 applications such as Steam. NixOS supplies the GNOME and GTK portals
for file selection and screen sharing.

## configuration

Edit [`config.kdl`](../modules/home/niri/config.kdl) for Niri. Home Manager installs it at
`~/.config/niri/config.kdl`. It preserves the existing display setup:

- Uranium's KTC H27T22 (DP-3) uses 2560×1440 at 165 Hz, scale 1, position 0,0.
- Uranium's Acer H233H (HDMI-A-1) uses 1920×1080 at 60 Hz, scale 1, position
  2560,368.
- eDP-1 uses its preferred mode and scale 2.

The external monitors are matched by make, model and serial, not by connector.
Tungsten's Intel GPU also has DP-3 and HDMI-A-1 connectors. A connector match
would apply Uranium's mode and position to any monitor plugged into the laptop.

Home Manager copies [`noctalia.toml`](../modules/home/niri/noctalia.toml) to
`~/.config/noctalia/config.toml` only when that file does not exist. The seed
enables authentication prompts and the lockscreen, including locking before
suspend, and turns off fingerprint unlock, since neither workstation runs
fprintd. It also seeds the idle timers: lock after 10 minutes, screen off
after 11, lock and suspend after 15. Later rebuilds preserve the file.

Noctalia's settings UI and `noctalia msg config-set` write to
`~/.local/state/noctalia/settings.toml`, which overrides `config.toml`. Idle
behaviour set there overrides the seeded timers on that machine. Setting only an idle
behaviour's `enabled` key through `config-set` writes a timeout of 0, so set
its `timeout` in the same pass. Application-specific Catppuccin themes remain
managed by Nix.

`Mod+Alt+L` locks the session and `Mod+Shift+Delete` locks and suspends.
`Shift+F13` captures the focused window, alongside the region and fullscreen
screenshot binds.

Validate the compositor file with `niri validate -c modules/home/niri/config.kdl`.
Build both workstation toplevels before deploying. A successful build cannot
verify physical monitor modes, GPU rendering or application launches in a live
session.

## workstation system

`modules/nixos/workstation` is imported by Tungsten and Uranium.

- **Kernel.** `linuxPackages_latest` through `mkDefault`, so a host can fall back
  to LTS without `mkForce`. Transparent huge pages are `always` with `defer`
  defrag, which gives games and builds huge pages without each one opting in,
  and without stalling a frame to compact memory. Servers keep `madvise`,
  because Postgres and Redis do worse with it on.
- **15-second unit timeouts.** A hung unit otherwise holds shutdown at "a stop job
  is running" for 90 seconds. Servers keep the default, since a database
  flushing on stop can take that long.
- **`enableStrictShellChecks`** runs shellcheck over every generated unit script
  and adds `set -o nounset`. It is workstation-only. On Helium it broke
  paperless-scheduler, whose pre-start reads `$CREDENTIALS_DIRECTORY`, and every
  host built cleanly before failing at activation. Read each generated script
  before turning it on for a server.
- **Packages.** The Nix language servers, nixfmt and nix-ld live here, not on
  servers. `environment.defaultPackages` is empty (add `strace` when debugging a
  hang) and speechd is off, which saves several hundred MiB.
- **Journals** are capped at 100M, for debugging the current boot. Servers keep the
  default, because history matters there.
- **earlyoom** acts on free memory and swap before the desktop stalls, where
  systemd-oomd waits for cgroup pressure. `--avoid` lists the session and things
  that cannot restart unnoticed, and `--prefer` lists what is cheap to lose.
  Patterns match the 15-character `comm` name, and `-g` takes a browser's
  renderers with it. earlyoom needs `systembus-notify`, which smartd turns off,
  so the workstation forces it on.
- **Fonts.** JetBrains Mono NL (no ligatures) and the `NFM` Nerd Font Mono
  family, which keeps glyphs single-width in terminals.
- **Containers.** Rootless podman with a `docker` shim. There is no daemon and
  no root-equivalent group. DNS is on for the default network, because compose
  files expect containers to resolve each other. Images are pruned weekly,
  since Nix's GC never touches them.

## boot

- **Lanzaboote** forces systemd-boot off, because both claim the ESP and nixpkgs
  allows exactly one loader. The boot editor is off, because it would let anyone
  at the keyboard append `init=/bin/sh`. New entries get three tries:
  systemd-bless-boot marks one good at `boot-complete.target`, and an entry that
  runs out of tries sorts last, so a generation that never finishes booting
  rolls back. A unit that fails before that target counts as a failed boot too.
  `bootctl list` shows the remaining tries. Microsoft's keys are enrolled
  because the discrete GPUs' option ROMs are signed with them.
- **Graphical boot.** `autologinOnce` logs tty1 in once per boot, which is all
  the fish login hook needs to start Niri. Logging out lands on a password
  prompt. Kernel parameters hide the logo, cursor and fbcon handover between
  Plymouth and the compositor. `loader.timeout = 0` hides the menu, and holding
  a key still shows it.

## hardware

- **MX Master 3S.** The thumb button emits no `BTN_*` event, so logiops claims it
  over HID++ and synthesises key combos through uinput, which Niri binds.
  Solaar is installed only to read the device name. Its `userService` must stay
  off, because it drives HID++ on the same device. The gesture button's CID is
  `195` (0xc3).
- **YubiKey.** pcscd must run, or every YubiKey age identity fails to decrypt,
  including `just restore-keys`. `age-plugin-yubikey` is on PATH for interactive
  `agenix -d`. agenix's activation uses a wrapped `age` with the plugin on its
  PATH, because activation's PATH is nearly empty. gpg's scdaemon is told
  `disable-ccid`, so it shares the card through pcscd instead of claiming the
  USB device outright.

## home-manager

`modules/home/default.nix` goes to every host, servers included, so it has no
compilers or language runtimes. Toolchains are in `workstation.nix`. It
installs ghostty's terminfo, because ssh does not carry terminfo across.
Catppuccin's `autoEnable` makes theming opt-out.

- **git** signs with the primary key in `keys/pgp.asc`. The private half is on
  the YubiKey, and only workstations run a gpg-agent, so a commit made on a
  server is refused rather than written unsigned. The lazygit theme is migrated
  at build time, because lazygit would try to rewrite its read-only config.
  Drop that once catppuccin/lazygit ships the new layout.
- **gpg** uses drduh's hardened defaults. `require-secmem` refuses to run rather
  than let a passphrase reach swap. `throw-keyids` hides recipients, at the cost
  of clients that cannot try every key (Mailvelope).
- **ssh** has one alias per host, addressed by tailnet IP, opening
  `tmux new -As0`, so a dropped link reconnects into the same session. One-shot
  commands need `-o RemoteCommand=none`. `knot.biscuits.at` and `tangled` alias
  to the knot's tailnet listener, because the public name goes through
  Cloudflare, which carries no SSH.
- **The YubiKey age identity** in `yubikey.nix` is a stub naming a serial and a
  slot, not a key, so it can be public. Workstations list its path in
  `age.identityPaths`.
- **Atuin** syncs ciphertext to Argon. Run `atuin register` once, then
  `atuin key` to carry the key to another machine. Atuin owns Ctrl-R, and fzf
  keeps Ctrl-T and Alt-C. `nix-your-shell` keeps fish inside `nix develop`.
- **Obsidian** runs on Electron 44, because 43.8.3 breaks its renderer preload.
- **nix-search.** manix is pointed at this flake's nixpkgs and home-manager
  through `NIX_PATH`. Left alone it falls through to nix-darwin's options and
  answers with Darwin defaults. Run `manix -u` after a flake update. `ns` is an
  fzf pipeline over nix-search-tv, which indexes for about twenty seconds on
  first run.
- **Niri** starts xwayland-satellite on demand. Noctalia's config is seeded once
  as a regular file. Its settings UI writes to a separate state file.
