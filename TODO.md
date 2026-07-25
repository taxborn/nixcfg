# TODO

Things around the config I want to remember to do.

This is the rebuild plan. Argon and Carbon are barebones on this config; Helium,
Uranium, and Tungsten still run the old config at `~/dev/nixcfg` and get formatted
in that order (but see [host format order](#host-format-order)).

Ordering rules, in priority:

1. Foundation lands while the machines are empty. Cross-cutting changes are
   cheapest to get wrong now, and that window narrows with every service that
   comes up.
2. Backups precede data. Immich and Paperless hold the only irreplaceable bytes.
3. Formatting is gated by hard blockers. Those are marked **blocker** below.

## Phase 0 — foundation

All on Argon/Carbon, before Helium is touched.

- [ ] Port `mySnippets`: `tailnet` (name + IPs), `mischief-town.networkMap`
      (domains/ports), `ssh/known-hosts`. Nearly every service module reads
      `config.mySnippets.*`, and port/vhost assignments are miserable to untangle
      once services are live.
- [x] Home-manager base. `modules/home/base.nix` is `{ }` and nothing sets
      `home-manager.users.taxborn`, so HM is wired into the flake but inert. Port
      `homes/default.nix` and the `profile-default` module — every host formatted
      after this lands usable instead of a bare TTY.
- [ ] Monitoring client. Standalone and tiny; adding it now means history exists
      by the time the server does.

## Phase 1 — server profile + Caddy

- [ ] `profiles/server` (base + btrfs + podman + caddy + fail2ban). Get it right
      against two hosts that can afford to break.
- [ ] Caddy, with the tailscale + cloudflare plugins and `tailscale/caddyAuth.age`.
      The linchpin — every user-facing service is downstream, and the tailnet-bound
      vhosts (Grafana, Paperless, Immich) need the plugin.
- [ ] `website` (taxborn.com). Smallest real vhost; proves ACME and the deploy path.
- [ ] fail2ban with the Caddy jail, now that something public exists to protect.

## Phase 2 — backups, before anything holds data

- [ ] Backups client, rsync.net target only (Helium's repo doesn't exist yet).
      Argon/Carbon carry almost nothing right now, which is exactly why this is the
      moment: prove the module, the per-host secret layout, and the retention rules
      against data that doesn't matter.
- [ ] **Test restore.** Not optional. Everything in Phase 4 and 6 assumes this works.

## Phase 3 — Helium

Blockers to clear first: `disko/btrfs-helium`, systemd-boot (Phase 0), the
`/mnt/hdd` external-drive mount, host entry in `modules/flake/hosts.nix`, root key
→ rekey.

- [ ] Format Helium barebones. Verify Tailscale, SSH, base.
- [ ] Backups server on Helium (borg repos on the HDD).
- [ ] Flip Argon/Carbon clients to dual-target rsync + Helium. Two destinations
      live before any data exists.

## Phase 4 — services, on Carbon

Ordered by pain-if-absent.

- [ ] Vaultwarden. Highest personal impact, small module, one secret.
- [ ] Forgejo. Needs Postgres plus three secrets, and the `postgresqlDumpAll`
      backup path — which is why Phase 2 came first.
- [ ] Once Forgejo is deployed, migrate this configuration there and update all
      GitHub links to the respective Forgejo link.
- [ ] forgejo-runner (Argon/Helium), registry-deploy.
- [ ] Glance.
- [ ] atproto stack: PDS + gatekeeper (the only podman consumer), tangled-knot,
      tangled-spindle.
- [ ] Minecraft.

## Phase 5 — monitoring server, on Argon

- [ ] Grafana + Prometheus + Loki. Deliberately after services exist; a dashboard
      of nothing isn't worth the sequencing cost.

## Phase 6 — Helium data services

- [ ] Immich.
- [ ] Paperless.
- [ ] Add both to the backup set in the *same commit* that enables them.

## Phase 7 — workstations

The largest gap. None of this exists in the new config yet:

- [ ] `disko/luks-btrfs-mirror` (parameterized per host).
- [ ] Flake inputs: `lanzaboote`, `catppuccin`.
- [ ] Bootloader: lanzaboote module.
- [ ] Hardware: amd gpu, intel gpu, nvidia gpu, `profiles/laptop`.
- [ ] NixOS: `profiles/workstation`, `desktop/hyprland`, sddm, yubikey,
      claude-desktop.
- [ ] Home: hyprland config, waybar, wofi, mako, hypridle, ghostty, zed, neovim
      config tree, yubikey, gpg, `profile-workstation`.
- [ ] Format first workstation, then the second.

Two bootstrap chicken-and-eggs to plan for:

- The workstation profile puts `/home/taxborn/.config/age/yubikey-identity.txt` in
  `age.identityPaths`. That file doesn't exist on a freshly formatted host, so
  secrets won't decrypt until it's placed.
- `sbctl create-keys` must run **before** lanzaboote is enabled. Install with
  systemd-boot, enroll, then flip.
