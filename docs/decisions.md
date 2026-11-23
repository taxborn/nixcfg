# decisions

Settings that look removable and are not, plus settings that were removed on
purpose. Read this before restoring something that is gone or deleting
something that looks unused. Git history has the full reviews these came from,
2026-09-05 (maintenance) and 2026-09-06 (architecture), deleted in the
2026-11 simplification.

## retained

- **OVH EF02 partition.** It is used. Disko derives
  `boot.loader.grub.devices = [ "/dev/sda" ]` from it, so NixOS installs BIOS
  GRUB to that disk as well as EFI GRUB to the ESP. A check of the singular
  `boot.loader.grub.device` misses the generated target.
- **bees deduplication stays opt-in.** `homelab.btrfs.deduplicate` is set
  nowhere. Its enabled branch, evaluated on Uranium, starts one bees daemon per
  distinct filesystem with a 2 GiB hash table each. Turn it on only when
  duplicate data is measured to justify that.
- **Uranium's initrd AES and HWP settings.** The reasoning stays in the host
  file. The [kernel documentation](https://docs.kernel.org/admin-guide/pm/intel_pstate.html#active-mode-with-hwp)
  separates the performance hint from the governor.
- **Monitoring roster lists.** `homelab.monitoring.alwaysOn` and
  `physicalDisks` have readers. The server splits scrape jobs on `alwaysOn`, and
  the client asserts `physicalDisks` against `services.smartd.enable`.
- **The backup client on every host.** There is no switch to turn it off. A host
  without backups should be a deliberate edit to `modules/nixos/common`, not a
  flag.
- **Caddy's admin API is off.** `enableReload = false`, so nothing calls it, and
  it listens on `127.0.0.1:2019` with no authentication. Any local user, such as
  the `agent` user on Helium, could rewrite the config through it. If reload is
  ever turned on, move the API to a mode 0600 unix socket instead of removing
  `admin off`.

## removed

- **Immich dashboard link, server Java, Mako's mpv.** Nothing in the tree used
  them.
- **fail2ban cross-jail escalation.** SSH is the only service jail. Incremental
  bans and tailnet exemptions remain.
- **Host photos.** They added no configuration or recovery value.
- **Mako and Hypridle.** Replaced by the Niri and Noctalia session in
  2026-09. See [desktop](./desktop.md).
- **The CI runner GC recipe.** The runner is retired. If it returns, its PID
  namespace and rootless Podman notes are in git history before `26a1827`.

## 2026-11 simplification

The homelab is not expected to grow past five hosts, so the configuration
dropped the machinery that was there for growth.

- **No enable switches.** A host imports the role, hardware and services it
  runs. A switch set in exactly one place was indirection with no second
  caller.
- **One settings file.** `homelab.nix` holds the host list, domains, ports,
  identity and other values used in more than one place. `modules/options.nix`
  types it as `homelab.*`. `secrets/secrets.nix` imports the same file, which
  is why it stays plain data.
- **No roster checks.** The build list, secret rules, tailnet map and borg keys
  all read `homelab.hosts`, so the assertions that they agreed were removed.
  The per-secret recipient check in `modules/nixos/common/fleet.nix` stays.
- **The backup server is placed by data.** `homelab.backupServer.host` names
  it, and the module turns its server half on there. Every client reads the
  same value for its target, so the two cannot disagree.
