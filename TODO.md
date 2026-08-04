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
- [ ] Configure waybar, wofi and mako. All three ship as bare packages today and
      run at their defaults. Neovim is still an unconfigured `systemPackages`
      entry from `base`.
- [ ] Declare `security.pam.services.hyprlock`. home-manager's
      `programs.hyprlock` writes config, but PAM is a NixOS-level concern, so
      the lock screen is authenticating against some other service's stack.

## Tungsten

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
- Do not disable `CapsuleFirmwareUpdate`. It reads like it belongs with
  `BIOSConnect` and `FOTA`, which are off, but it is the UEFI capsule path fwupd
  itself delivers through — turning it off removes the update route that was the
  reason for disabling Dell's.
- Do not disable `MSUefiCA`. The NVIDIA option ROM is signed by the Microsoft
  third-party UEFI CA, so dropping it from db risks a machine that will not POST.
- Do not enable `AdvBatteryChargeCfg` or `PeakShiftCfg`. Either one overrides
  `PrimaryBattChargeCfg`, silently undoing the 50/90 charge limit.
- BIOS writes through `dell_wmi_sysman` need the admin password first: as root,
  write it to `authentication/Admin/current_password`, then write attribute
  values. Without it every write returns `EACCES`.
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
