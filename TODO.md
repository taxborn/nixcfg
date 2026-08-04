# TODO

What is left. Everything here is open — finished work is in git history.

## Services

- [ ] Repoint the GitHub self-link in `README.md` (the reference-commit link).
      The other `github.com` links credit other people's configs and stay.
- [ ] forgejo-runner (Argon/Helium), registry-deploy.
- [ ] Glance.
- [ ] atproto stack: PDS + gatekeeper (the only podman consumer), tangled-knot,
      tangled-spindle.
- [ ] Minecraft.
- [ ] Grafana + Prometheus + Loki, on Argon.
- [ ] Immich and Paperless, on Helium. Add both to the backup set in the *same
      commit* that enables them — they hold the only irreplaceable bytes here.

## Workstation desktop

- [ ] Flake input: `catppuccin`.
- [ ] sddm and claude-desktop. sddm may be moot: the workstation profile starts
      Hyprland from fish's login shell on VT1 instead.
- [ ] Configure waybar, wofi and mako. All three ship as bare packages today and
      run at their defaults. Neovim is still an unconfigured `systemPackages`
      entry from `base`.
- [ ] Declare `security.pam.services.hyprlock`. home-manager's
      `programs.hyprlock` writes config, but PAM is a NixOS-level concern, so
      the lock screen is authenticating against some other service's stack.

## Tungsten

- [ ] BIOS `PrimaryBattChargeCfg` reads `Express`, not Custom, so the stored
      `CustomChargeStart=50` / `CustomChargeStop=90` are inert and the pack
      fast-charges to 100%. Set it to `Custom`. Sysfs reports 50/90 either way —
      `dell_laptop` shows the stored values, not the active mode — so it is not
      evidence the limit is applied.
- [ ] BIOS `Absolute` → `DisableAbsolute`. A firmware-resident persistence agent
      that exists to inject itself into a running Windows install; dead weight
      here. Not `PermanentlyDisabled`, which is irreversible and buys nothing.
- [ ] BIOS `BIOSConnect` → Disabled, and `FOTA` with it. The firmware's own
      HTTPS client for Dell-hosted recovery; the CVE-2021-2157x chain was this
      path, and fwupd covers updates.
- [ ] BIOS `FirmwareTamperDet` is `Silent` → `Enabled`, so detection says so.
- [ ] Battery replacement, eventually. 40.5 Wh of an 84.3 Wh design pack, which
      halves every runtime number on this machine.

Every BIOS attribute is readable and writable from the OS through
`dell_wmi_sysman`:

```
sudo sh -c 'for a in /sys/class/firmware-attributes/dell-wmi-sysman/attributes/*/; do
  printf "%-28s %-16s %s\n" "$(basename $a)" "$(cat $a/current_value)" "$(cat $a/possible_values 2>/dev/null)"
done'
```

## Do not

Decisions that are cheap to forget and expensive to redo.

- Do not disable `UsbPortsExternal` or `UsbEmu` on Tungsten. The FIDO2 LUKS key
  is a USB YubiKey, so that locks the machine out of its own root filesystem.
- Do not lower `TelemetryAccessLvl` from `Full`. It plausibly gates the Dell
  Data Vault that `dell_wmi_ddv` reads for fan RPM and battery telemetry.
- Clear the firmware PK (Expert Key Management → Delete All Keys) *before* ever
  reinstalling a lanzaboote host. `/var/lib/sbctl` lives on the encrypted root,
  so formatting destroys the keys and `autoEnrollKeys` needs setup mode.
- Hibernation: decided against. s2idle measures 0.56 W, about three days closed,
  so there was no drain problem to solve. It would cost ~36 GiB of `nodatacow`
  swap on the mirror plus a `resume_offset` read off the created file and pasted
  into `kernelParams` — imperative state this config works to avoid.
- Fingerprint: the reader cannot enrol. Supported by libfprint, but it measures
  50 coverage against a hardcoded threshold of 65, and the thresholds are
  CRC-protected constants. See `e1141ed`.
