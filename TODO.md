# TODO

Things around the config I want to remember to do.

This is the rebuild plan. Argon, Carbon, and Helium run this config. Uranium and
Tungsten are the last two on the old config at `~/dev/nixcfg`; both have host
configs here that evaluate, and neither machine has been formatted yet.

Ordering rules, in priority:

1. Foundation lands while the machines are empty. Cross-cutting changes are
   cheapest to get wrong now, and that window narrows with every service that
   comes up.
2. Backups precede data. Immich and Paperless hold the only irreplaceable bytes.
3. Formatting is gated by hard blockers. Those are marked **blocker** below.

## Phase 1 — server profile + Caddy

- [x] `profiles/server` (base + btrfs + caddy + fail2ban). Get it right against
      two hosts that can afford to break. Podman was in the original sketch and
      is not in the profile — nothing needs it yet, so it arrives with the
      atproto stack in Phase 4 or not at all.
- [x] Caddy, with the tailscale + cloudflare plugins and `tailscale/caddy.age`.
      The linchpin — every user-facing service is downstream, and the tailnet-bound
      vhosts (Grafana, Paperless, Immich) need the plugin.
- [x] fail2ban with the Caddy jail, now that something public exists to protect.

## Phase 2 — backups, before anything holds data

- [x] Backups client, rsync.net target only (Helium's repo doesn't exist yet).
      Argon/Carbon carry almost nothing right now, which is exactly why this is the
      moment: prove the module, the per-host secret layout, and the retention rules
      against data that doesn't matter.
- [x] **Test restore.** Not optional. Everything in Phase 4 and 6 assumes this works.
      Verified across all three hosts and both repositories, including a restore
      from a machine holding nothing but the yubikey. `just restore-all` re-runs
      the whole matrix; see the backups module README.

## Phase 3 — Helium

Blockers to clear first: `disko/btrfs-helium`, systemd-boot (Phase 0), the
`/mnt/hdd` external-drive mount, host entry in `modules/flake/hosts.nix`, root key
→ rekey.

- [x] Format Helium barebones. Verify Tailscale, SSH, base.
- [x] Backups server on Helium (borg repos on the HDD).
- [x] Flip Argon/Carbon clients to dual-target rsync + Helium. Two destinations
      live before any data exists.

## Phase 4 — services, on Carbon

Ordered by pain-if-absent.

- [x] Vaultwarden. Highest personal impact, small module, one secret.
- [x] Forgejo. Landed on Postgres, then moved to SQLite once it was clear one
      user does not need a second daemon to patch and version-pin. Two secrets
      either way (SMTP; the signing key makes two) — neither engine needs a
      database password. The backup dump path landed with it, which is why
      Phase 2 came first; it is now `sqliteDatabases` rather than
      `postgresqlDumpAll`, and the Postgres option stays for whatever brings a
      cluster back (Immich, Paperless). Git over SSH is tailnet-only on
      Forgejo's builtin server, port 2222: the web domain cannot carry SSH
      (Cloudflare's proxy is HTTP-only) and port 22 cannot either (Tailscale SSH
      intercepts it on the tailnet and skips the forced command). See the module
      README.
- [x] Migrate this configuration to Forgejo. `origin` is
      `ssh://git@carbon.<tailnet>:2222/taxborn/nix.git`, over the builtin SSH
      server on the tailnet.
- [ ] Repoint the one remaining GitHub self-link — the reference-commit link in
      `README.md`. The other `github.com` links are credits to other people's
      configs and third-party sources, and stay as they are.
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

Was the largest gap; now it is mostly the desktop. Storage, boot, hardware, and
backups are in place for both hosts and evaluate clean. What is left is the
graphical half, plus a secrets bootstrap that cannot clear until each machine
has been installed once.

Landed:

- [x] `disko/btrfs-luks-raid1`, parameterized per host — ESP + mdraid RAID1 +
      LUKS (FIDO2-enrolled) + btrfs, with optional `games` and `backup`
      companion drives sitting off the mirror. Uranium takes both; Tungsten
      takes neither.
- [x] Fallback ESP on the second drive, installed to by the layout itself rather
      than by each host, with an assertion so a future host cannot take the
      partition and silently leave it empty — which is exactly the shape
      Tungsten had.
- [x] Flake input: `lanzaboote`.
- [x] Bootloader: lanzaboote module, with declarative key generation and
      enrollment. Both workstations use it; Tungsten no longer uses
      systemd-boot.
- [x] Hardware: `amd/gpu` (Uranium), `nvidia/gpu` (Tungsten), `intel/cpu`.
- [x] NixOS: `profiles/workstation`, `services/yubikey`.
- [x] Home: `profile-workstation`, git, gpg, ssh, yubikey.
- [x] Backups on both workstations, with `desktopExcludes` so a desktop `/home`
      does not ship its caches and Steam runtimes off-site nightly. Snapper's
      `.snapshots` directories are derived from `profiles/btrfs` rather than
      excluded by hand, so the next snapshotted subvolume is covered too.

Still missing:

- [ ] Flake input: `catppuccin`.
- [ ] Hardware: intel gpu, `profiles/laptop` — Tungsten currently has no
      thermald, lid handling, or power management at all.
- [ ] NixOS: `desktop/hyprland`, sddm, claude-desktop.
- [ ] Home: hyprland config, waybar, wofi, mako, hypridle, ghostty, zed, neovim
      config tree.
- [ ] Confirm Tungsten's drive sizes with `lsblk -b -d` and check `raidSize`
      against them before formatting. It is `920G` now; the previous `930G` did
      not leave room for the second drive's own 4G ESP, and would have failed
      the `disko` run outright if the PC801 is a nominal 1TB part.
- [ ] Format Uranium, then Tungsten.

### secrets bootstrap, per workstation

**blocker** for backups on both hosts, and for either machine reaching the
tailnet unattended. Neither host's root key exists yet, so neither is a recipient
of anything under `secrets/`:

- [ ] Install, then collect `/etc/ssh/ssh_host_ed25519_key.pub` into
      `keys/root_<host>.pub`, add the host to the `hosts` list in
      `secrets/secrets.nix`, rekey, and rebuild.
- [ ] Provision borg key material for both — steps 1-4 of the backups module
      README, including the `authorizedKeys` entry on Helium. Until this lands,
      activation reports a failed decrypt and borgmatic has no passphrase.

The old note here said the yubikey age identity "doesn't exist on a freshly
formatted host." Half true now: `modules/home/programs/yubikey.nix` writes it
declaratively, but home-manager runs as a systemd service, well after
`agenixInstall` in the activation script — so it is still absent for the first
activation. The sharper problem is that `/run/agenix` is tmpfs, so falling
through to the yubikey identity means the key has to be present and PIN-unlocked
on *every* boot before tailscaled can read its auth key. Getting the host key
into `secrets.nix` is what actually fixes this.

Secure Boot needs no bootstrap step any more. The old note — install under
systemd-boot, run `sbctl create-keys`, enroll, then flip to lanzaboote — is
superseded: the lanzaboote module generates the keys and stages the enrollment
itself, so a fresh install reaches enforcing Secure Boot on its own.
