# nixos homelab configuration

this repository holds my nixos configuration for all of my hosts. five machines,
three servers and two workstations, built from one flake with home-manager,
agenix, and disko.

## documentation

| document | what it covers |
| --- | --- |
| [AGENTS.md](./AGENTS.md) | working in this repo: what to run, what not to run, the invariants, known drift |
| [CONTEXT.md](./CONTEXT.md) | the vocabulary and the recurring practices: namespaces, snippets, profiles, restore tiers |
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
modules/disko/         disk layouts, instantiated per host in modules/flake
modules/users/         the taxborn account
homes/                 home-manager profiles: default, server, workstation
hosts/<host>/          per-host config, plus proxy.nix where the host runs Caddy
secrets/               agenix .age files and the secrets.nix rule file
keys/                  public keys: host roots, yubikey, the origin-pull cert
scripts/               operational bash, invoked from the justfile
```

`import-tree` picks up Nix files under the hardware, NixOS, home, users and
snippets module directories. Creating a module there is the registration step.
Disk layouts are instantiated in `modules/flake/modules.nix`. Keep the host
rosters in `modules/flake/hosts.nix`, `secrets/secrets.nix` and
`mySnippets.tailnet.tailscaleIPs` in agreement.

## day to day

```bash
just update              # rebuild this machine
just update <host>       # rebuild a remote host over ssh
just check               # run every pre-commit hook over the whole tree
just deploy-site         # bump the braxton.is lock and rebuild carbon
just clean               # nix-collect-garbage -d
```

The devShell installs the hook set through direnv, so a `cd` into the repo is
the setup step. `nix flake check` evaluates every host and runs the same hooks.

Build a host without switching to it:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

## provisioning a new host

1. create a generic host under [hosts/](./hosts) and add its name to the list in
   [modules/flake/hosts.nix](modules/flake/hosts.nix) (reference commit [138a32e](https://github.com/taxborn/nixcfg/commit/138a32e6aebe9c11ce35fcecd2cd64acafc5337b))
2. enable root login by an SSH key (I'd likely want to use my
   [personal SSH key](./keys/yubikey.pub)) on the host
3. `nix run github:nix-community/nixos-anywhere -- --flake .#<host-name> --target-host root@<ip address>`
4. collect the installed host's `/etc/ssh/ssh_host_ed25519_key.pub` into
   `keys/root_<host>.pub`, add the host to `secrets/secrets.nix`, and
   `agenix -r`. see [secrets/](./secrets/README.md#adding-a-host)
5. add the host to `mySnippets.tailnet.tailscaleIPs`, or it is neither addressed
   by the fleet nor backed up
6. generate its borg material and initialize its repositories. see the
   [backups README](./modules/nixos/services/backups/README.md#provisioning-a-host)

Steps 4 through 6 are in that order because agenix activation fails on a missing
`.age` file. Until a host is a recipient, every rebuild reports a failed decrypt
for every secret its modules ask for.

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

## todo

Open work from the architecture review, in priority order.

- [x] Register database backup requirements in the service modules when the
  backup client is enabled. Forgejo and Piper currently rely on dump settings
  in Argon's host config, which could be missed when moving either service.
  Keep repository and retention choices at the host level. Read the
  [backups README](./modules/nixos/services/backups/README.md) before changing
  this integration.
- [x] Check agreement between the host roster, tailnet map and secret
  recipients automatically. Make restore coverage explicit too; `restore-all`
  currently exercises only the three servers. Start with assertions, and
  consider a shared inventory only if it simplifies those checks.
- [ ] Move host-specific disk layout instantiation and serial numbers out of
  `modules/flake/modules.nix` and into the host directories. Extract the MX
  Master button configuration from the workstation profile into a hardware
  module, so the profile mostly selects modules.
- [ ] Give `mySnippets.biscuits-at.networkMap` typed entries instead of
  unrestricted attributes. Validate required fields and port types, reject
  misspelled fields, and retain the shared service/proxy registry.
- [ ] Give repeated architectural rules and operational explanations one
  authoritative home across README, CONTEXT and AGENTS, with links elsewhere.
  Move the completed maintenance table below into a dated review document.
  Preserve the detailed backup and security reasoning when consolidating.

## maintenance review

Reviewed on 2026-09-05 against the pinned inputs and evaluated host options.
The original TODO and known-drift list produced these changes and decisions.

| item | decision |
| --- | --- |
| host platform tied to Intel CPU | Each host now declares its architecture. All five still evaluate with the Intel CPU module disabled. |
| i915 keyed on CPU | Gate it on Intel graphics. Checked both CPU/GPU combinations. |
| braxton.is and PDS port collision | Reserve 3006 for the site. Its service and Caddy read the same option. |
| Mako unit | Keep it. Pinned home-manager creates no unit. Document its D-Bus and session lifecycle, and restart on failure. |
| Hypridle overrides | Use home-manager's session-target option and restart policy. Retain the PATH needed by idle commands. |
| dead runner GC recipe | Remove the recipe and preserve the PID namespace and rootless Podman notes in [modules/](./modules/README.md#retired-runner). This does not decide whether a runner returns. |
| unread monitoring options | Remove `alwaysOn` and `physicalDisks`. Preserve the liveness and SMART distinctions in [modules/](./modules/README.md#snippets-hold-data-no-config). |
| fail2ban cross-jail escalation | Remove it. SSH is the only service jail; incremental bans and tailnet exemptions remain. |
| OVH BIOS partition | Keep it. Disko derives the BIOS GRUB target from EF02, alongside the EFI install. The drift report missed `grub.devices`. |
| btrfs device records | Replace the unused mount-point records with unique device paths. |
| bees deduplication | Keep it disabled by default. Evaluating the enabled branch on Uranium produces three daemons and three 2 GiB hash tables. No measured space saving justifies enabling them. |
| Immich dashboard link | Remove it. No module or proxy in this tree provides the service, and no external use was identified during review. |
| server Java and Mako mpv | Remove them. No configured command uses either package. |
| Uranium's deleted comments | Restore the initrd AES and HWP preference reasoning. The [kernel documentation](https://docs.kernel.org/admin-guide/pm/intel_pstate.html#active-mode-with-hwp) distinguishes the performance hint from the governor. |
| Neovim/tmux navigation | Install the missing Neovim plugin and map normal-mode C-hjkl to its commands. |
| em dashes | Apply unslop to new and rewritten prose. Keep unrelated punctuation cleanup out of functional changes. |
| host photos | Drop the placeholder. Photos need actual host images and add no configuration or recovery instructions. |

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
