{
  self,
  pkgs,
  config,
  modulesPath,
  ...
}:
let
  net = config.mySnippets.mischief-town.networkMap;
in
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
    profiles.btrfs.enable = true;
    programs = {
      grub.enable = true; # grub seems to be the only bootloader that works on ovh
      nix.enable = true;
      podman.enable = true;
    };
    services = {
      # backups.client = {
      #   enable = true;
      #   extraExcludes = [
      #     "/var/lib/containers"
      #     "/var/lib/gitea-actions-runner"
      #     "/var/lib/caddy"
      #   ];
      #   repositories = {
      #     rsync = {
      #       path = "ssh://de4388@de4388.rsync.net/./borg-repos/argon";
      #       label = "rsync";
      #       remotePath = "borg14";
      #     };
      #     helium = {
      #       path = "ssh://taxborn@${net.tailscaleIPs."helium-01"}//mnt/hdd/borg-repos/argon";
      #       label = "helium";
      #     };
      #   };
      # };
      caddy.enable = true;
      node-exporter.enable = true;
      promtail = {
        enable = true;
        lokiUrl = "http://${net.tailscaleIPs."helium-01"}:${toString net.loki.port}";
      };
      forgejo-runner = {
        enable = true;
        dockerContainers = 3;
        nativeRunners = 2;
      };
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
