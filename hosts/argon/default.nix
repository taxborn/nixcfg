{
  self,
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
    ./proxy.nix
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
      backups.client = {
        enable = true;
        enableRsyncRepo = true;
        enableHeliumRepo = true;
        extraExcludes = [
          "/var/lib/containers"
          "/var/lib/caddy"
        ];
      };
      caddy.enable = true;
      node-exporter.enable = true;
      fluent-bit = {
        enable = true;
        lokiHost = net.tailscaleIPs."helium-01";
        lokiPort = net.loki.port;
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
      hash-haus.enable = true;
      minecraft.servers.tbd = {
        enable = true;
        directory = "/home/taxborn/public/tbd";
        port = 25565;
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
