{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myNixOS.programs.lanzaboote;
in
{
  options.myNixOS.programs.lanzaboote.enable = lib.mkEnableOption "secure boot with lanzaboote";

  config = lib.mkIf cfg.enable {
    boot = {
      # The workstation layout enrolls a FIDO2 key against the LUKS volume and
      # asks for it through crypttab options, which only the systemd initrd
      # reads. Without this the key is ignored and boot falls back to the
      # passphrase set at install time. See modules/disko/btrfs-luks-raid1.nix.
      initrd.systemd.enable = lib.mkDefault true;

      loader = {
        efi.canTouchEfiVariables = lib.mkDefault true;

        systemd-boot = {
          # Lanzaboote installs through `boot.loader.external` and does not turn
          # systemd-boot off on its own, so without this two installers claim
          # the ESP and the build fails nixpkgs' "exactly one bootloader"
          # assertion.
          enable = lib.mkForce false;

          # Still read by lanzaboote, which seeds loader.conf from these. The
          # boot editor lets anyone at the keyboard append `init=/bin/sh` to the
          # kernel command line, walking straight around everything Secure Boot
          # just verified, and nixpkgs leaves it on.
          editor = lib.mkDefault false;
        };
      };

      lanzaboote = {
        enable = true;
        configurationLimit = lib.mkDefault 10;

        # New entries get three boot attempts. systemd-bless-boot marks one good
        # once boot-complete.target is reached, and an entry that runs out of
        # tries sorts last, so a generation that never finishes booting rolls
        # back on its own. The catch is that a failed unit ordered before that
        # target counts as a failed boot too, so a service that breaks on every
        # start can quietly send a machine back to the previous generation.
        # `bootctl list` shows the remaining tries.
        bootCounting.initialTries = lib.mkDefault 3;
        pkiBundle = lib.mkDefault "/var/lib/sbctl";
        autoGenerateKeys.enable = lib.mkDefault true;
        autoEnrollKeys = {
          enable = lib.mkDefault true;
          autoReboot = lib.mkDefault true;
          # Load bearing on any machine with a discrete GPU. Option ROMs are
          # signed by Microsoft, and firmware that will not validate one can
          # leave the card with no output.
          includeMicrosoftKeys = lib.mkDefault true;
        };
      };
    };

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
