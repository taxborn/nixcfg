{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.serverBase = {
    enable = lib.mkEnableOption "shared server bundle (caddy, fail2ban, tailscale, backups client, btrfs, impermanence)";
  };

  config = lib.mkIf config.myNixOS.profiles.serverBase.enable {
    myNixOS = {
      base.enable = true;
      profiles = {
        btrfs.enable = true;
        impermanence.enable = true;
      };
      programs = {
        nix.enable = true;
        podman.enable = true;
      };
      services = {
        backups.client = {
          enable = true;
          enableRsyncRepo = true;
          enableHeliumRepo = true;
        };
        caddy.enable = true;
        tailscale.enable = true;
        fail2ban = {
          enable = true;
          enableCaddyJail = true;
        };
      };
    };

    myHardware.intel.cpu.enable = true;
  };
}
