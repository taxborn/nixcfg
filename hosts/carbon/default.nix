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
  # homestead server w mavs
  networking.firewall.allowedTCPPorts = [
    25565
    24454 # voice chat requirement?
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
      backups.client = {
        enable = true;
        repositories = {
          rsync = {
            path = "ssh://de4388@de4388.rsync.net/./borg-repos/carbon";
            label = "rsync";
            remotePath = "borg14";
          };
          helium = {
            path = "ssh://taxborn@100.64.1.0//mnt/hdd/borg-repos/carbon";
            label = "helium";
          };
        };
      };
      caddy.enable = true;
      forgejo.enable = true;
      node-exporter.enable = true;
      promtail = {
        enable = true;
        lokiUrl = "http://100.64.1.0:3100";
      };
      forgejo-runner = {
        enable = true;
        dockerContainers = 3;
        nativeRunners = 2;
      };
      glance.enable = true;
      pds.enable = true;
      tailscale = {
        enable = true;
        operator = "taxborn";
      };
      tangled-knot.enable = true;
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
