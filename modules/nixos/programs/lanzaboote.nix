{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.programs.lanzaboote.enable = lib.mkEnableOption "secure boot with lanzaboote";

  config = lib.mkIf config.myNixOS.programs.lanzaboote.enable {
    boot = {
      initrd.systemd.enable = lib.mkDefault true;

      loader = {
        efi.canTouchEfiVariables = lib.mkDefault true;

        systemd-boot = {
          # Lanzaboote installs itself through `boot.loader.external` and does
          # not turn systemd-boot off on its own, so this has to be explicit —
          # otherwise two installers claim the ESP and the build fails on
          # nixpkgs' "exactly one bootloader" assertion.
          enable = lib.mkForce false;

          # Still read by lanzaboote, which seeds its loader.conf from these.
          #
          # The boot editor lets anyone at the keyboard append to the kernel
          # command line — `init=/bin/sh` included — which walks straight around
          # everything Secure Boot just verified. nixpkgs defaults it on, so
          # signing the boot chain without turning this off buys much less than
          # it appears to.
          editor = lib.mkDefault false;
        };
      };

      lanzaboote = {
        enable = true;
        configurationLimit = lib.mkDefault 10;
        pkiBundle = lib.mkDefault "/var/lib/sbctl";

        # The key material is provisioned by two systemd units rather than by
        # hand, which is what makes a fresh install reach enforcing Secure Boot
        # without an out-of-band `sbctl create-keys` step:
        #
        #   generate-sb-keys        runs `sbctl create-keys`, guarded by
        #                           ConditionPathExists on ${pkiBundle}/keys so
        #                           it fires exactly once
        #   prepare-sb-auto-enroll  exports PK/KEK/db as EFI authenticated
        #                           variables into $ESP/loader/keys/auto, then
        #                           re-runs lzbt to sign every artifact now that
        #                           there is a key to sign with
        #
        # Enabling autoEnrollKeys also sets `secure-boot-enroll = force` in
        # loader.conf, which is what makes systemd-boot pick those files up and
        # enroll them into firmware on the following boot.
        #
        # The bootstrap works because `allowUnsigned` defaults to
        # autoGenerateKeys.enable: during nixos-install no key exists yet, so
        # lzbt is permitted to install unsigned artifacts, and the first boot
        # replaces them with signed ones.
        autoGenerateKeys.enable = lib.mkDefault true;

        autoEnrollKeys = {
          enable = lib.mkDefault true;

          # Reboot as soon as the .auth files are staged, so enrollment happens
          # on the next boot instead of waiting for the operator to notice.
          autoReboot = lib.mkDefault true;

          # Load bearing on any machine with a discrete GPU: option ROMs are
          # signed by Microsoft, and firmware that will not validate one can
          # leave the card without output. Lanzaboote asserts on this rather
          # than letting it through silently — the only way to drop these keys
          # is the explicit `allowBrickingMyMachine`.
          includeMicrosoftKeys = lib.mkDefault true;
        };
      };
    };

    # Not required by the units above, which call sbctl by store path. This is
    # for `sbctl status` and `sbctl verify` when checking what firmware actually
    # ended up enrolling.
    environment.systemPackages = [ pkgs.sbctl ];
  };
}
