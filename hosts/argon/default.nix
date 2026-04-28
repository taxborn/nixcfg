{
  self,
  modulesPath,
  ...
}:
{
  imports = [
    ./home.nix
    ./secrets.nix

    self.diskoConfigurations.btrfs-argon
    self.nixosModules.locale-en-us

    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = "argon";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

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

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}
