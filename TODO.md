# TODO

Things around the config I want to remember to do.

This is the rebuild plan, and the rebuild itself is done: all five hosts —
Argon, Carbon, Helium, Tungsten, and Uranium — are formatted and running this
config. What is left is services and the graphical half of the workstations.

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

Was the largest gap; now it is nearly closed. Storage, boot, hardware, backups,
and secrets are in place on both hosts, and both are installed and running this
config. What is left is theming and the parts of the desktop that are installed
but unconfigured.

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
- [x] Hardware: `intel/gpu` and `profiles/laptop` — thermald on the full DPTF
      stack, tuned, upower, and PRIME offload with an `nvidia-sync`
      specialisation. The tuning gaps that turned up once the machine was
      running are Phase 8.
- [x] Confirmed Tungsten's drive sizes. The WD SN550 is the smaller of the two
      at 931.5 GiB, so its own 4G ESP leaves 927.5 GiB for its raid partition;
      `raidSize = "920G"` on the PC801 clears that with room to spare.
- [x] Format Tungsten. RAID1 is assembled across both NVMes, both ESPs are
      mounted, and Secure Boot is enrolled and enforcing with a measured UKI.
- [x] Format Uranium. On the tailnet at 100.64.0.0 and running the same
      revision as every other host.
- [x] Home: the Hyprland config tree (`modules/home/desktop/hyprland`, with the
      lua split), plus ghostty and zed. `programs/hyprland.nix` installs waybar,
      wofi, mako and the hypr* tools, and enables hyprlock and hypridle.

Still missing:

- [ ] Flake input: `catppuccin`.
- [ ] NixOS: sddm and claude-desktop. sddm may be moot — the workstation
      profile starts Hyprland from fish's login shell on VT1 instead.
- [ ] Configure what is merely installed: waybar, wofi and mako all ship as
      packages with no config of their own, so they run at their defaults.
      Neovim is still an unconfigured `environment.systemPackages` entry from
      `base`.
- [ ] `security.pam.services.hyprlock` is not declared. home-manager's
      `programs.hyprlock` writes config but PAM is a NixOS-level concern, so
      hyprlock is falling back to another service's stack rather than its own.

### secrets bootstrap, per workstation

Cleared on both. Each host's root key is in `keys/`, both are in the `hosts`
list in `secrets/secrets.nix`, both have borg passphrase and SSH key material
under `secrets/borg/`, and Helium's `authorizedKeys` admits both:

- [x] Tungsten: root key, secrets recipient, borg material. Backups running.
- [x] Uranium: same, and Helium authorizes its borg key.

Resolved, and worth keeping for the next host. The concern was the yubikey age
identity: `modules/home/programs/yubikey.nix` writes it declaratively, but
home-manager runs as a systemd service well after `agenixInstall` in the
activation script, so it is absent for the very first activation. The sharper
edge was that `/run/agenix` is tmpfs, so falling through to the yubikey identity
would mean the key had to be present and PIN-unlocked on *every* boot before
tailscaled could read its auth key. Getting each host key into `secrets.nix` is
what fixed it, and both workstations are in that list now — so this only bites
again in the window between installing a sixth host and rekeying for it.

Secure Boot needs no bootstrap step any more. The old note — install under
systemd-boot, run `sbctl create-keys`, enroll, then flip to lanzaboote — is
superseded: the lanzaboote module generates the keys and stages the enrollment
itself, so a fresh install reaches enforcing Secure Boot on its own.

One caveat that only applies to a *re*install: Tungsten's firmware is now in
deployed mode with lanzaboote's keys enrolled, and `/var/lib/sbctl` lives on the
encrypted root. Formatting from scratch destroys those keys, and `autoEnrollKeys`
needs setup mode — so the PK has to be cleared in firmware (Expert Key Management
→ Delete All Keys) *before* reinstalling, or the fresh install will not boot.

## Phase 8 — Tungsten hardware pass

Tungsten is installed and running this config, so this phase is tuning rather
than bring-up. The measurements that set the ordering, all taken on the machine:

- Awake draw is 12-14 W, against a battery that has aged to 48% of design
  capacity — 40.5 Wh of 84.3 Wh. That is under three hours of runtime.
- s2idle is not the problem. A 9h25m closed-lid stretch cost 13 points, about
  0.56 W, so the machine holds roughly three days asleep.
- Boot is 25.3s: 5.5s firmware, 3.1s loader, 0.8s kernel, 5.7s initrd (mostly
  waiting on the YubiKey touch), 10.2s userspace.

So the battery work is entirely about the awake half, and the boot work is
mostly firmware settings rather than anything in this config.

- [x] **blocker** `homes/workstation.nix` did not parse — a missing `;` after
      `configPath`, `programs` bound twice in the same attribute set, and a
      `firefix` typo. The flake had not evaluated since `3dbe844`. The two
      `programs` blocks are merged and `firefox` no longer appears in
      `home.packages`, where it duplicated what `programs.firefox` installs.
      `configPath` stays and is now commented: home-manager warns about it
      because `home.stateVersion` is below 26.05, and the profile on Tungsten
      already lives under XDG, so dropping it would point the module at a
      directory that does not exist.

- [x] The dGPU never enters RTD3. `modules/hardware/nvidia/gpu.nix` loads the
      nvidia modules from `boot.initrd.kernelModules`, so the driver binds
      before switch-root — and the stage 2 udev rules that set
      `power/control=auto` only fire on a `bind` action, which by then has
      already happened. `runtime_suspended_time` is 0 for the whole session and
      the card has been powered continuously; this is the prime suspect for the
      12-14 W. Keep `i915` in the initrd — that is what the Hyprland wiki note
      in that file is actually about — and move the four nvidia modules to
      `boot.kernelModules`. `boot.initrd.kernelModules` is now `btrfs dm_mod
      i915` with the four nvidia modules in stage 2. **Still to confirm after
      the next boot:**
      `cat /sys/bus/pci/devices/0000:01:00.0/power/{control,runtime_status}`
      should read `auto` / `suspended` with nothing using the dGPU, and the
      awake draw in `upower` should fall well below 12 W.

- [x] `services.hardware.bolt.enable` in `profiles/laptop`. The Thunderbolt
      security level is `user`, so devices need explicit authorization and there
      is nothing running to grant it. Any TB4 dock silently does nothing today.

- [x] `services.fwupd.enable` in `profiles/workstation`. The 9520 is fully
      covered on LVFS, and with custom Secure Boot keys, capsule updates through
      fwupd are the only realistic path to a current BIOS — Dell's own updaters
      are not an option here.

- [x] `options iwlwifi power_save=1` in `profiles/laptop`. The AX211 defaults to
      `power_save=0`, and nixos-hardware sets this for exactly this model. Skip
      the `disable_11ax=1` that ships alongside it there; that works around a
      2021 regression and on 7.1 it only costs throughput.

- [x] Fill out `modules/hardware/intel/gpu.nix`: add `vpl-gpu-rt` (the Gen12+
      encode runtime) and `intel-compute-runtime` (OpenCL), plus an
      `extraPackages32`. The nvidia module turns on `enable32Bit`, so right now
      there is no 32-bit VAAPI at all and wine/Steam fall back to software
      decode.

- [x] Deprioritize `borgmatic.service` fleet-wide — `Nice = 19`,
      `IOSchedulingClass = "idle"`, `CPUSchedulingPolicy = "idle"`. Its timer is
      `OnCalendar=daily` with `Persistent=true`, which on a laptop asleep at
      midnight means every run is a catch-up firing the instant the lid opens;
      it last ran at 07:12:46, the same second as resume. The schedule is right
      and should stay — what is wrong is that a 90-second backup competes with
      the desktop coming up. Deliberately *not* `ConditionACPower` on this one:
      a skipped condition does not retry, so a laptop that lives on battery
      would quietly stop backing up.

- [x] `ConditionACPower = true` on `nix-gc` and `nix-optimise` in
      `profiles/laptop`. Pure housekeeping, harmless to skip, and unlike
      borgmatic nothing is lost by waiting for a wall. Each is guarded on the
      option that creates the unit in the first place, so the profile stays
      safe on a host that has not enabled automatic gc or optimise.

- [x] Dropped `services.fstrim` to `monthly` in `base.nix`. Every btrfs mount
      in `modules/disko` already carries `discard=async` and the LUKS volumes
      allow discards, so the weekly pass was close to redundant — and it still
      cost 2m8s of I/O on its last run. Fleet-wide, deliberately: the
      reasoning holds on every host here.

The BIOS turned out to be in good shape already. Dumped and checked against all
131 attributes, the following were **already correct** and need no visit:
`Fastboot=Minimal`, `ExtPostTime=0s`, `FullScreenLogo=Disabled`,
`UefiNwStack=Disabled`, `SdCardBoot=Disabled`, `ThunderboltBoot=Disabled`,
`SupportAssistOSRecovery=Disabled`, `AllowBiosDowngrade=Disabled`,
`InternalDmaCompatibility=Disabled`, `PreBootDma=Enabled`,
`SmmSecurityMitigation=Enabled`, `AdminSetupLockout=Enabled`,
`CapsuleFirmwareUpdate=Enabled`, `MSUefiCA=Enabled`,
`MasterPasswordLockout=Disabled`, `SecureBoot=Enabled`,
`SecureBootMode=DeployedMode`, `TpmSecurity=Enabled`, `KernelDma=Enabled`,
`Virtualization`/`VtForDirectIo=Enabled`, `EmbSataRaid=Ahci`,
`TpmPpiClearOverride=Disabled`, `DellCoreService=Disabled`,
`VerticalIntegration=Disabled`, every `WakeOn*` and `AutoOn` disabled,
`BlockSleep=Disabled`, `ForceLpmAspmOff=Disabled`, `IntelSagv=Enabled`,
`Itbm=Enabled`, `CStatesCtrl`/`SpeedShift`/`Speedstep`/`TurboMode=Enabled`,
`ThermalManagement=Optimized`, `UefiBootPathSecurity=AlwaysExceptInternalHdd`.

Boot speed in particular has nothing left in it — `Fastboot` was already Minimal
and `ExtPostTime` already 0, so 5.5s is roughly the floor for this firmware.

What actually needs changing:

- [ ] `PrimaryBattChargeCfg` is **`Express`**, not Custom. `CustomChargeStart=50`
      and `CustomChargeStop=90` are stored but inert while the mode is Express,
      which fast-charges to 100%. Given the pack has aged to 48% of design, that
      is very likely part of why. Set the mode to `Custom` so the 50/90 pair
      takes effect. (Note the sysfs `charge_control_*_threshold` files read 50
      and 90 regardless — `dell_laptop` reports the stored values, not the
      active mode, so they are not evidence the limit is being applied.)

- [ ] `Absolute` is `EnableAbsolute`. Set it to **`DisableAbsolute`** — a
      firmware-resident persistence agent that exists to inject itself into a
      running Windows install, dead weight on NixOS, and a documented attack
      surface. Deliberately not `PermanentlyDisabled`, the third option: that
      one is irreversible in firmware and buys nothing over `DisableAbsolute`.

- [ ] `BIOSConnect` is `Enabled`. Disable it. It is the firmware's own HTTPS
      client for Dell-hosted recovery and updates — the CVE-2021-2157x
      "BIOSDisconnect" chain was exactly this path, pre-boot code execution
      through its TLS handling. With custom Secure Boot keys and fwupd it has
      no job here. `FOTA=Enabled` can go with it for the same reason; there is
      no WWAN module in this machine.

- [ ] `FirmwareTamperDet` is `Silent`, which detects but stays quiet. `Enabled`
      surfaces the alert instead. On a personal machine the notification is the
      entire value of the feature.

Explicitly leaving alone, with reasons, so these do not get "hardened" later:

- `UsbPortsExternal` and `UsbEmu` stay **Enabled**. The FIDO2 LUKS unlock is a
  USB YubiKey; disabling external USB ports would lock the machine out of its
  own root filesystem.
- `TelemetryAccessLvl=Full` stays. It plausibly gates Dell Data Vault, which is
  what `dell_wmi_ddv` reads for fan RPM and battery telemetry — the `dell_ddv`
  hwmon exposing `fan1_input`/`fan2_input` today. Not worth trading working
  sensors for a telemetry setting that goes nowhere without `DellCoreService`.
- `SignOfLifeByDisplay` and `SignOfLifeByKbdBacklight` stay Enabled. An earlier
  draft of this list had them off for boot speed; with `Fastboot` already
  Minimal they are worth a few hundred milliseconds at most, against being the
  only sign the machine responded to the power button for five seconds.
- `IPv4PXEBoot`, `IPv6PXEBoot`, and `HttpsBoot` read Enabled but are subordinate
  to `UefiNwStack=Disabled` and are therefore inert. Turning them off is
  cosmetic; harmless either way.
- `ThunderboltPorts=Enabled` and `DisUsb4Pcie=Disabled` are what make TB4 and
  PCIe tunnelling work at all. Safe to keep given `KernelDma`, `PreBootDma`,
  and now boltd.

      All 131 settings are readable from the OS through `dell_wmi_sysman`, and
      writable with the admin password, so this could eventually be declarative.
      One `sudo` around a POSIX shell rather than a fish loop calling `sudo` per
      attribute — 131 password-cached invocations is slow, and the `do` in a
      shell loop is a syntax error in fish anyway:

      ```
      sudo sh -c 'for a in /sys/class/firmware-attributes/dell-wmi-sysman/attributes/*/; do
        printf "%-28s %-16s %s\n" "$(basename $a)" "$(cat $a/current_value)" "$(cat $a/possible_values 2>/dev/null)"
      done'
      ```

- [ ] Battery replacement. A hardware call rather than a config one, but it is
      the largest single factor in runtime here — 40.5 Wh of an 84.3 Wh design
      pack. Everything above is fighting for watts against a battery that has
      lost half its capacity.

Decided against:

- Hibernation. It wants a ~36 GiB `nodatacow` swap subvolume on the mirror
  (written twice, once per drive) plus a `resume_offset` that has to be read off
  the created file and pasted into `kernelParams` — imperative state in a config
  that works hard to avoid it. The case for it was s2idle drain, and the
  measurement above removed that: 0.56 W is about three days closed. What is
  left is preserving a session across a flat battery, and a cold boot is 25.3s
  of which the firmware, loader, and YubiKey touch are all paid by a resume too.
  Worth revisiting only if the workload starts needing disk swap for its own
  sake, at which point `suspend-then-hibernate` comes along nearly free.
