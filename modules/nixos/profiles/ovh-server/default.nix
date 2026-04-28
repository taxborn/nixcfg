{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.ovhServer = {
    enable = lib.mkEnableOption "OVH KVM server bundle (caddy, tailscale, fail2ban, backup client, impermanence, intel/ssd hardware)";
  };

  config = lib.mkIf config.myNixOS.profiles.ovhServer.enable {
    myNixOS = {
      base.enable = true;
      profiles = {
        btrfs.enable = true;
        impermanence = {
          enable = true;
          extraUserDirs = [ "public" ];
        };
      };
      programs = {
        grub.enable = true; # grub seems to be the only bootloader that works on ovh
        nix.enable = true;
        podman.enable = true;
      };
      services = {
        backups.client = {
          enable = false;
          enableRsyncRepo = true;
          enableHeliumRepo = true;
          extraExcludes = [
            "/var/lib/containers"
            "/var/lib/caddy"
          ];
        };
        caddy.enable = true;
        tailscale = {
          enable = true;
          operator = "taxborn";
        };
        fail2ban = {
          enable = true;
          enableCaddyJail = true;
        };
      };
    };

    myHardware = {
      intel.cpu.enable = true;
      profiles = {
        ovh.enable = true;
        ssd.enable = true;
      };
    };
  };
}
