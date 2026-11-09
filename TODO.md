# TODO

Ideas from comparing against [isabelroses/dotfiles](https://github.com/isabelroses/dotfiles).
Check each option with `nix eval` before adopting, and build `uranium` and
`tungsten` in full.

## done

- `workstation`: kernel behind `mkDefault`, 15s systemd timeouts, earlyoom.
- kernel: THP `always`/`defer` on workstations, `kexec_load_disabled` on all
  hosts, `iommu=pt` and `usbcore.autosuspend=-1` on `uranium`, boot cosmetics
  in `graphical-boot`. `legacy_tiocsti` and `dmesg_restrict` were already at
  the wanted values.
- nix: `keep-going`, `log-lines`, `warn-dirty`, `keep-outputs`,
  `keep-derivations`, `accept-flake-config = false`, host-overridable
  `min-free`/`max-free` (5G/20G on `uranium`).
- workstation home: `atuin` (local only), `lazygit`, `nix-your-shell`,
  `nix-output-monitor`, `dix`, `pwvucontrol`. `bat`, `direnv`, `eza` and
  `zoxide` were already there.
- boot: lanzaboote `bootCounting.initialTries = 3` on both workstations. The
  boot editor was already off. Verified on both after a reboot:
  `systemd-bless-boot` marks the booted entry good and strips its `+N` suffix,
  while unbooted entries such as tungsten's `nvidia-sync` specialisation keep
  `tries: 3 left`. The rollback path itself is untested.
- laptop: `tuned` battery detection and upower 20/5/2 were already the
  defaults. Critical action is now `PowerOff`, since the `HybridSleep` default
  needs a hibernation path that `noresume` and zram swap rule out.
- kernel: `kptr_restrict`, `fs.protected_fifos` and `fs.protected_regular` at 2
  on all hosts.
- `workstation`: empty `environment.defaultPackages` (drops perl, rsync, strace).
- atuin: argon's archive carries the `atuin` database. Verified by extracting
  `borgmatic/postgresql_databases/localhost/all` and finding its `history` and
  `users` tables.
- vaultwarden: argon's archive carries the `vaultwarden` SQLite dump. Verified
  with `borgmatic list --archive latest --find vaultwarden`, which found
  `borgmatic/sqlite_databases/localhost/vaultwarden`. It had been archived as
  live files before. The dump itself was listed, not extracted and opened.
- argon: removed the retired runner's `/var/lib/forgejo-runner`. Its Nix store
  volume was still being backed up and made borg warn about special files. Old
  archives keep carrying it until they age out of retention.
- backups: each host's borg key is confined to `borg serve --restrict-to-path`
  on its own repository on Helium, served on port 2200. Backups to Helium
  worked from every host after deploying Helium first, and `just restore-dr`
  for argon passed through the forced command. Other hosts' `restore-dr` runs
  are not recorded here. The keys are not append-only, so a host can still
  prune its own repository, and port 22 still reaches a shell by tailnet
  identity until the tailnet ACLs say otherwise.
- backups: the five rsync.net borg keys carry
  `command="borg14 serve --restrict-to-path /data1/home/de4388/borg/<host>",restrict`
  by hand, so a compromised host can no longer touch another host's offsite
  repository. Done on 2026-10-06. A backup to rsync.net and
  `just restore-dr` for argon passed afterward. The refusal of a key on another
  host's repository was not recorded as tested, and the keys are not
  append-only.
- `workstation`: `enableStrictShellChecks`. Tried on every host and reverted
  for servers, see the comment in `workstation.nix`. A clean build is not
  evidence: `nounset` broke `paperless-scheduler` on Helium at activation.
- `workstation`: journald caps, `udisks2`, speechd
  and nano off.

## open

Most of this list comes from the 2026-11-09 config and security review. It is
ordered by how much each item shrinks the worst case.

- minecraft, deploy step: the servers now run as a `minecraft` service account
  from `/var/lib/minecraft/<name>`, and the unit cannot see `/home`. Each world
  has to be moved once, by hand. The socket unit changed, so the switch may
  stop the server. It then stays skipped until the jar exists at the new path.
  For `mnb` on argon, and the same for `mavs-updated` on carbon:

  ```bash
  just update argon
  # then on the host
  sudo systemctl stop minecraft-mnb.service
  sudo cp -a /home/taxborn/public/mnb/. /var/lib/minecraft/mnb/
  sudo chown -R minecraft:minecraft /var/lib/minecraft/mnb
  sudo systemctl start minecraft-mnb.service
  systemctl status minecraft-mnb.service
  ```

  `cp -a` needs room for a second copy of the world. Remove
  `/home/taxborn/public/<name>` once players have connected, then delete this
  entry. The sandbox has not run against a live pack. If a mod fails on
  startup, read the journal for the denied path or address family before
  loosening anything.
- minecraft: move `mnb` off argon. The service account closes the path to
  root, but an internet-facing JVM with third-party mods still shares a host
  with Vaultwarden, the PDS master key and both forges. Carbon already runs
  one server and holds far less.
- caddy: `secrets/tailscale/caddy.age` holds a Cloudflare `Zone:DNS:Edit`
  token encrypted to all five hosts, but only argon and helium use DNS-01.
  Carbon decrypts it at activation, because `caddy.nix` declares the secret
  wherever Caddy runs, and carbon runs CI as root. Narrow the recipients in
  `secrets/secrets.nix`, declare the secret only where a vhost imports
  `cloudflare-dns`, and change the `fleet.nix` assertion that requires every
  host. Then scope the token down and rotate it. Git history keeps the old
  ciphertext, which all five host keys can open.
- tailscale: the tailnet is one flat trust zone and its policy is not in this
  repo. Every host trusts `tailscale0`, runs Tailscale SSH and has IP
  forwarding on, so "tailnet only" means "any tailnet node". Check the policy
  file in here and apply it from here. Tag the hosts, with carbon as `tag:ci`
  allowed to reach argon 443, helium 2200 and helium 3100 and nothing else.
  Allow Tailscale SSH from the workstations only. Check that
  `tailscale/auth.age` is a tagged or single-use key. Set
  `useRoutingFeatures` to `"client"` unless a host is an exit node.
- monitoring: two outages cannot page anyone. Alerts leave helium through
  ntfy on argon, so `InstanceDown` for argon has nowhere to go, and nothing
  outside helium notices when helium stops. Add an email receiver for
  `severity="critical"` through the Fastmail relay, and an always-firing rule
  that pings an outside dead-man service.
- users: `hashedPassword` in `modules/users/taxborn.nix` is in a repo pushed
  to a public knot. It is the sudo password on all five hosts. Move it to
  `hashedPasswordFile` from an agenix secret, then change the password so the
  published hash is dead.
- ssh listeners: Forgejo's SSH on 2222, the knot's on 2223 and helium's borg
  sshd on 2200 bind every interface, and the closed firewall is all that
  keeps them on the tailnet. Bind each to
  `myNixOS.services.tailscale.address` with `bindOrdering`, as AdGuard, Loki
  and the exporters do. For sshd use `listenAddresses`, so 2200 exists only
  on the tailnet address. Deploy helium before the clients.
- backups: pin rsync.net's host key in `programs.ssh.knownHosts`, since the
  first connection still trusts it on first use. Add a `just` recipe that
  fetches rsync.net's `authorized_keys` and diffs it against entries generated
  from the roster, because nothing here can confirm the forced commands.
  Confirm the account's server-side snapshot schedule and record it in the
  backups README. The keys are not append-only, so those snapshots are the one
  copy a compromised host cannot prune.
- caddy: nothing watches HTTP logins. The only fail2ban jails are sshd and
  Minecraft, and Alloy skips Caddy's access logs on the ground that fail2ban
  reads them. Ship the access logs for the direct vhosts to Loki, or add a
  jail for them.
- forgejo: `federation.ENABLED` is on for a single-user forge with
  registration closed. Turn it off unless something uses it.
- helium: its disk is plain btrfs and it is the one server in a house, with
  the Paperless archive on it. Decide between leaving it, for unattended
  reboots, and LUKS with TPM2 unlock. Record the answer in the README's
  "do not" list either way.
- caddy: the `caddy-tailscale` plugin looks unused. The only Tailscale
  feature a vhost uses is `get_certificate tailscale`, which is core Caddy.
  Confirm with a build of argon before removing it and its hash.
  `trusted_proxies` is also server-wide, so Caddy believes `X-Forwarded-For`
  on the direct PDS vhosts when the peer is in a Cloudflare range. Tranquil
  reads the entry Caddy appended, so the effect stops at Caddy's own logs.
- checks: add a `just` recipe that diffs the Cloudflare ranges in `caddy.nix`
  against the published list. On carbon a missing range is a partial outage.
  Run `nix flake check --no-build` from a pre-push hook, since the
  architecture and restore regressions otherwise run only when remembered. It
  takes about 20 seconds.
- docs, drift found in the same review:
  - `hosts/README.md` and the backups README say carbon has no database. The
    spindle registers a SQLite dump.
  - The host tables in `hosts/README.md` leave out Minecraft on argon and
    carbon, and `braxton.is` on carbon.
  - The inventory in `secrets/README.md` is missing the two Grafana files and
    the two Tangled keys. Its ntfy ACL example grants only the `backups`
    topic, and monitoring needs `alerts` as well.
  - `keys/README.md` does not list `braxton-is-deploy.pub`.
  - `monitoring/alerts.nix` and `dashboards.nix` describe helium's external
    drive as NTFS under ntfs-3g. It is btrfs.
  - `monitoring/default.nix` says fail2ban watches Caddy's access logs. That
    jail was removed in the 2026-09-05 review.
  - `services/tailscale.nix` says the trusted interface makes loopback-bound
    services reachable over the tailnet. It makes Caddy and tailnet-bound
    sockets reachable.
  - The 2026-09-05 review records the server JDK as removed. `58bbc03` put
    `jdk17_headless` back in `homes/server.nix` for running the packs by hand
    as `taxborn`. The Minecraft unit calls Java by store path, so drop it
    again.
  - `CONTEXT.md` calls the site "the odd one out" among lock-driven deploys
    without saying how it deploys now, a CI tarball over a forced-command SSH
    key.

Before any `just update` on a host running Postgres, compare
`datcollversion` with `pg_database_collation_actual_version(oid)` in
`pg_database`. A mismatch needs `REINDEX DATABASE` then `ALTER DATABASE ...
REFRESH COLLATION VERSION` first. Argon needed it, Helium did not.

## notes

- Never add BPF JIT hardening on `uranium`. `scx_lavd` needs the JIT.
- `brightnessctl` is installed on tungsten only, in the host file. Niri routes
  brightness keys through Noctalia, so the package is for manual use on the
  laptop panel. External monitors need DDC, which is not wired up.

## evaluated and skipped for now

- Declined: initrd zstd `-19` (ESP is not tight), `use-xdg-base-directories`,
  `flake-registry = ""`, `auto-allocate-uids`, `keep-sorted` hook. `jj` is
  parked until wanted, it needs a name and email for `programs.jujutsu`.
- Kernel hardening params (`slub_debug`, `page_poison`, `lockdown`,
  `module.sig_enforce`, `oops=panic`), `nohz_full`, forced PTI, `ptrace_scope=3`.
- `userborn` / `etc.overlay` / `nixos-init`. Possible clash with agenix
  activation, test on a throwaway host.
- `zswap` instead of zram. Needs a disk swap device.
- Check her git history for settings she reverted before adopting more.
