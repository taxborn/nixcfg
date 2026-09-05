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

`import-tree` picks up every file under `modules/`, so creating a file is the
whole registration step. There is no import list to add it to. The only rosters
that exist are the host list in `modules/flake/hosts.nix` and the one in
`secrets/secrets.nix`.

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

Open work and unanswered questions. The [known drift][drift] list in AGENTS.md
carries the detail on why each of these reads as load-bearing and is not.

[drift]: ./AGENTS.md#known-drift

- Move `nixpkgs.hostPlatform` out of `modules/hardware/intel/cpu.nix`. Every
  host's platform currently depends on a CPU-vendor module being enabled, which
  holds only because all five enable it.
- Key the i915 initrd gate in `modules/hardware/nvidia/gpu.nix` on the GPU
  rather than on `myHardware.intel.cpu.enable`. The comment above it is about
  graphics; the condition is about the CPU.
- Rewrite the reasoning `50743d4` and `83016a3` removed from Uranium: why
  `aesni_intel` belongs in the initrd, and why `cpu-epp` rather than
  `powerManagement.cpuFreqGovernor`. Both fail silently, which is the bar the
  comment style sets for keeping an explanation forever.
- Record why `modules/home/services/mako.nix` and `hypridle.nix` hand-write
  systemd units instead of taking home-manager's, or drop the overrides.
  `882efdc` introduced them with no reason given.
- Decide whether the Forgejo runner is coming back. If not, `just runner-gc`
  and the pid-namespace note it carries can go.
- Give Immich a `networkMap` entry if it is proxied from somewhere, or drop the
  dashboard link in `modules/nixos/services/glance.nix`.
- Drop either the EF02 BIOS-boot partition in `modules/disko/btrfs-ovh.nix` or
  the header claiming it is used; GRUB installs in EFI mode here.
- Remove the unread `mountPoint` field in `modules/nixos/profiles/btrfs.nix`,
  and decide whether `deduplicate` is wanted, since no host enables it.
- Drop `jdk_headless` from `homes/server.nix` and `mpv` from
  `modules/home/services/mako.nix`, or record what uses them.
- Settle the em dash question. The house voice uses them freely, most visibly
  in `caddy.nix`; the prose pass that touched most of the tree removed them
  only where a comment was being rewritten anyway, so the tree is mixed.

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
