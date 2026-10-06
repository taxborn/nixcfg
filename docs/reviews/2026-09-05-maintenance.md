# maintenance review, 2026-09-05

Reviewed on 2026-09-05 against the pinned inputs and evaluated host options.
The original TODO and known-drift list produced these changes and decisions.

| item | decision |
| --- | --- |
| host platform tied to Intel CPU | Each host now declares its architecture. All five still evaluate with the Intel CPU module disabled. |
| i915 keyed on CPU | Gate it on Intel graphics. Checked both CPU/GPU combinations. |
| braxton.is and PDS port collision | Reserve 3006 for the site. Its service and Caddy read the same option. |
| Mako unit | Keep it. Pinned home-manager creates no unit. Document its D-Bus and session lifecycle, and restart on failure. |
| Hypridle overrides | Use home-manager's session-target option and restart policy. Retain the PATH needed by idle commands. |
| dead runner GC recipe | Remove the recipe and preserve the PID namespace and rootless Podman notes in [modules/](../../modules/README.md#retired-runner). This does not decide whether a runner returns. |
| unread monitoring options | Remove `alwaysOn` and `physicalDisks`. Preserve the liveness and SMART distinctions in [modules/](../../modules/README.md#snippets-hold-data-no-config). |
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

## desktop follow-up, 2026-09-11

The Niri and Noctalia migration removes Mako, Hypridle and their local units.
The findings above describe the former desktop. Their unit-specific workarounds
no longer apply. See the [new session notes](../../modules/home/desktop/niri/README.md).

## retained settings

Retained settings that are easy to misread. The Mako and Hypridle bullet below
is superseded by the desktop follow-up above.

- The OVH EF02 partition is used. Disko derives
  `boot.loader.grub.devices = [ "/dev/sda" ]` from it. NixOS installs BIOS
  GRUB to that disk as well as EFI GRUB to the ESP. Checking only the singular
  `boot.loader.grub.device` misses the generated install target.
- Pinned home-manager configures Mako and registers its D-Bus package, but
  creates no systemd unit. The local unit starts it with Hyprland, waits for
  its bus name and stops it with the session. Hypridle does have an upstream
  unit and uses `services.hypridle.systemdTarget` in the home configuration.
- No host enables btrfs `deduplicate`. Its enabled branch was evaluated on
  Uranium and creates one bees daemon per distinct filesystem, each with a
  2 GiB hash table. Keep it opt-in until duplicate data justifies that cost.
- The retired runner's GC and monitoring distinctions live in
  [modules/README.md](../../modules/README.md). There is no runnable `runner-gc`
  recipe or configurable monitoring roster without their consumers.
