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
- ssh listeners: Forgejo's SSH, the knot's and helium's borg sshd bind the
  tailnet address with `bindOrdering`, and `federation.ENABLED` is off. Only
  evaluated and built. Not deployed. Deploy helium first, keep console access,
  then check `ss -ltn` for 2200 on the tailnet address only.
- caddy: `caddy-tailscale` removed, since only core `get_certificate tailscale`
  was in use. Builds on argon, helium and carbon, not yet run on a host.
- checks: `just check-cloudflare-ips` and a pre-push `nix flake check
  --no-build` hook. Only the no-drift path of the recipe was run.
- docs: the 2026-11-09 drift list is corrected, and `jdk17_headless` is gone
  from `homes/server.nix`.
- backups: rsync.net's ED25519 and ECDSA host keys are pinned, checked against
  a fresh scan and rsync.net's published fingerprints, but not against the
  PGP signature on that list. `just rsync-keys-check` diffs the account's
  `authorized_keys` against the roster. It needs the YubiKey and has not run
  against the real file until 2026-11-09, when it passed. The snapshot
  schedule is 7 days, recorded in the backups README.
- caddy: direct vhost access logs go to Loki through Alloy, with an
  `HttpLoginFailures` Loki rule. The PDS vhosts overwrite `X-Forwarded-For`
  with the TCP peer. Neither has run: check alloy, loki and the stream
  `{job="caddy-access"}` after deploying. Deploy helium before argon.
- users: the sudo password hash is an agenix secret
  (`secrets/users/taxborn-password.age`) and the password was changed, so the
  hash in git history is dead. Deployed to all five hosts.
- caddy: the Cloudflare token lives in `secrets/cloudflare/dns-token.age`,
  decrypted on argon and helium only, derived from which vhosts import
  `cloudflare-dns`. Deployed and Caddy starts. Open: revoke the old token
  after confirming DNS-01 with the new one, and note `tailscale/caddy.age`
  stays readable in git history until then.
- forgejo: removed with its runner, its port 2222 SSH server, the tailnet
  LFS vhost and the caddy cert permission it needed. The knot keeps 2223 and
  its aliases. Built only, not deployed. Before deploying argon, take a last
  Forgejo dump if anything in it is worth keeping, since retention will prune
  the archives that hold it. After deploying, remove `/var/lib/forgejo` on
  argon. On carbon, remove `/var/lib/forgejo-runner` and
  `/var/lib/forgejo-runner-credentials` before the next borgmatic run, since
  the runner's borg exclude is gone and its container layers would land in
  the archive. Check `ls /var/lib/systemd/linger` and `systemctl status
  user@990` there too, as the runner account lingered. Check the zone for
  explicit `code` and `git` records and delete them. Names left on the
  proxied wildcard 525 like any other unserved name. Revoke the Fastmail app
  password.

## open

Most of this list comes from the 2026-11-09 config and security review. It is
ordered by how much each item shrinks the worst case.

- minecraft: the worlds are moved to `/var/lib/minecraft/<name>`. Once players
  have connected, remove `/home/taxborn/public/<name>` on argon and carbon. The
  sandbox has not run against a live pack, so if a mod fails read the journal
  for the denied path or address family before loosening anything.
- minecraft: move `mnb` off argon. The service account closes the path to
  root, but an internet-facing JVM with third-party mods still shares a host
  with Vaultwarden, the PDS master key and the knot. Carbon already runs
  one server and holds far less.
- tailscale: the tailnet is one flat trust zone and its policy is not in this
  repo. Every host trusts `tailscale0`, runs Tailscale SSH and has IP
  forwarding on, so "tailnet only" means "any tailnet node". Check the policy
  file in here and apply it from here. Tag the hosts, with carbon as `tag:ci`
  allowed to reach helium 2200 and helium 3100 and nothing else.
  Allow Tailscale SSH from the workstations only. Check that
  `tailscale/auth.age` is a tagged or single-use key. Set
  `useRoutingFeatures` to `"client"` unless a host is an exit node.
- monitoring: two outages cannot page anyone. Alerts leave helium through
  ntfy on argon, so `InstanceDown` for argon has nowhere to go, and nothing
  outside helium notices when helium stops. Add an email receiver for
  `severity="critical"` through the Fastmail relay, and an always-firing rule
  that pings an outside dead-man service.
- helium: its disk is plain btrfs and it is the one server in a house, with
  the Paperless archive on it. Decide between leaving it, for unattended
  reboots, and LUKS with TPM2 unlock. Record the answer in the README's
  "do not" list either way.

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
