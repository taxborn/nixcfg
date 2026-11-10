# nixos homelab configuration

this repository holds my nixos configuration for all of my hosts. five machines,
three servers and two workstations, built from one flake with home-manager,
agenix, and disko.

## documentation

| document | what it covers |
| --- | --- |
| [AGENTS.md](./AGENTS.md) | working in this repo: what to run, what not to run, validation, permissions and comment policy |
| [CONTEXT.md](./CONTEXT.md) | vocabulary, deployment model and network policy |
| [hosts/](./hosts/README.md) | what each machine is and what it runs |
| [modules/](./modules/README.md) | how the module system is laid out and how to add to it |
| [secrets/](./secrets/README.md) | agenix rules, who can decrypt what, day-to-day commands |
| [keys/](./keys/README.md) | the public key material and what reads each file |
| [backups](./modules/nixos/services/backups/README.md) | borg/borgmatic, provisioning a host, restore testing |

## layout

```
flake.nix              inputs only; outputs are `import-tree ./modules/flake`
modules/flake/         flake-parts: host roster, module exports, packages, hooks
modules/nixos/         myNixOS.*      system options
modules/home/          myHome.*       home-manager options
modules/hardware/      myHardware.*   CPU / GPU / chassis
modules/snippets/      mySnippets.*   data-only registries, shared by both
modules/disko/         reusable disk layouts; hosts instantiate them
modules/users/         the taxborn account
homes/                 home-manager profiles: default, server, workstation
hosts/<host>/          per-host config, disko.nix and proxy.nix
secrets/               agenix .age files and the secrets.nix rule file
keys/                  public keys: host roots, yubikey, the origin-pull cert
scripts/               operational bash, invoked from the justfile
tests/                 evaluation regressions and mocked operational tests
docs/reviews/          dated maintenance and architecture decisions
```

See [module loading](./modules/README.md#how-a-module-gets-loaded) for imports
and disk layout ownership, and [fleet agreement](./modules/README.md#fleet-agreement)
for the checked rosters.

## day to day

```bash
just update              # rebuild this machine
just update <host>       # rebuild a remote host over ssh
just check               # run every pre-commit hook over the whole tree
just check-cloudflare-ips # diff caddy.nix's Cloudflare ranges against the published lists
just clean               # nix-collect-garbage -d
```

The devShell installs the hook set through direnv, so a `cd` into the repo is
the setup step. It also installs a pre-push hook that runs
`nix flake check --no-build`, so a push evaluates every host first. That hook
is pre-push only, so `just check` and `checks.pre-commit` skip it. `nix flake check` evaluates every host, runs those hooks, and
checks database registration, fleet agreement, network types and the restore
runner with mocked commands.

Build a host without switching to it:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

## provisioning a new host

1. Install with a temporary standalone configuration that enables root login
   with your [public SSH key](./keys/yubikey.pub). Keep this bootstrap
   configuration outside the fleet until the installed host has its root key.
   For example, run `nix run github:nix-community/nixos-anywhere -- --flake
   <bootstrap-flake>#<host> --target-host root@<ip-address>`.
2. Collect the installed host's `/etc/ssh/ssh_host_ed25519_key.pub` into
   `keys/root_<host>.pub`.
3. Add its final configuration and `disko.nix` under `hosts/<host>/`, then add
   its name to `modules/flake/hosts.nix`, `secrets/secrets.nix` and
   `mySnippets.tailnet.tailscaleIPs` together. Fleet assertions require agreement.
   Also add an entry to `mySnippets.ssh.knownHosts` in
   `modules/snippets/sshKnownHosts.nix`. No assertion checks it, and a missing
   host falls back to trust-on-first-use.
4. Follow [secret operations](./secrets/README.md#working-with-them) to rekey
   the shared secrets and register any service-specific recipients.
5. Complete the key-material and authorization steps in
   [backup provisioning](./modules/nixos/services/backups/README.md#provisioning-a-host)
   before the first rebuild of the final configuration.
6. Evaluate and build the host, then deploy it with `just update <host>` and
   initialize its backup repositories as described in that guide.

The standalone installation makes the root key available before the final
configuration requires it. Fleet assertions check file existence and recipient
rules; activation still needs the encrypted files to have been rekeyed.

## references

- [aly.codes](https://github.com/alyraffauf/nixcfg)'s nixcfg
- [isabelroses.com](https://github.com/isabelroses/dotfiles)'s configuration

## etc

Every BIOS attribute is readable and writable from the OS through
`dell_wmi_sysman`:

```
sudo sh -c 'for a in /sys/class/firmware-attributes/dell-wmi-sysman/attributes/*/; do
  printf "%-28s %-16s %s\n" "$(basename $a)" "$(cat $a/current_value)" "$(cat $a/possible_values 2>/dev/null)"
done'
```

## reviews

- [Maintenance review, 2026-09-05](./docs/reviews/2026-09-05-maintenance.md)
  records fixes and retained settings from the pinned-input review.
- [Architecture review, completed 2026-09-06](./docs/reviews/2026-09-06-architecture.md)
  records the five tasks from `26a1827` and their implementation.

## do not

Decisions that are cheap to forget and expensive to redo.

- Do not disable `UsbPortsExternal` or `UsbEmu` on Tungsten. The FIDO2 LUKS key
  is a USB YubiKey, so that locks the machine out of its own root filesystem.
- Do not lower `TelemetryAccessLvl` from `Full`. As far as I can tell it gates
  the Dell Data Vault that `dell_wmi_ddv` reads for fan RPM and battery
  telemetry, and I have not tried lowering it to find out.
- Do not disable `CapsuleFirmwareUpdate`. It looks like it belongs with
  `BIOSConnect` and `FOTA`, which are both off. It does not. This is the UEFI
  capsule path fwupd itself delivers through, so turning it off removes the
  update route that was the whole reason for disabling Dell's.
- Do not disable `MSUefiCA`. The NVIDIA option ROM is signed by the Microsoft
  third-party UEFI CA, so dropping it from db risks a machine that will not POST.
- Do not enable `AdvBatteryChargeCfg` or `PeakShiftCfg`. Either one overrides
  `PrimaryBattChargeCfg`, silently undoing the 50/90 charge limit.
- BIOS writes through `dell_wmi_sysman` need the admin password first. As root,
  write it to `authentication/Admin/current_password`, then write attribute
  values. Without it every write returns `EACCES`.
- Clear the firmware PK (Expert Key Management, Delete All Keys) *before* ever
  reinstalling a lanzaboote host. `/var/lib/sbctl` lives on the encrypted root,
  so formatting destroys the keys and `autoEnrollKeys` needs setup mode.
- Hibernation, decided against. s2idle measures 0.56 W, about three days on a
  closed lid, so there was no drain problem to solve. Enabling it costs ~36 GiB
  of `nodatacow` swap on the mirror, plus a `resume_offset` read off the created
  file and pasted into `kernelParams`. That is the imperative state this config
  works to avoid.
- Fingerprint, dead end. libfprint supports the reader, but it measures 50
  coverage against a hardcoded threshold of 65, and those thresholds are
  CRC-protected constants. See `e1141ed`.
