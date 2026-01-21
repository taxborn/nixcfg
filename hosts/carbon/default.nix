{
  self,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    ./home.nix
    ./proxy.nix
    ./secrets.nix

    self.diskoConfigurations.btrfs-carbon
    self.nixosModules.locale-en-us

    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = "carbon";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  environment.systemPackages = with pkgs; [
    jdk21_headless
  ];

  myNixOS = {
    base.enable = true;
    profiles.btrfs.enable = true;
    programs = {
      grub.enable = true; # grub seems to be the only bootloader that works on ovh
      nix.enable = true;
      podman.enable = true;
    };
    services = {
      backups = {
        enable = true;
        repository = "ssh://de4388@de4388.rsync.net/./borg-repos/carbon";
      };
      caddy.enable = true;
      forgejo.enable = true;
      forgejo-runner = {
        enable = true;
        dockerContainers = 3;
        nativeRunners = 2;
      };
      glance.enable = true;
      tailscale = {
        enable = true;
        operator = "taxborn";
      };
      taxborn-com.enable = true;
      vaultwarden.enable = true;
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
