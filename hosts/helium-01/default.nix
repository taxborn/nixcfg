{
  self,
  pkgs,
  config,
  ...
}:
let
  net = config.mySnippets.mischief-town.networkMap;
  tailnet = config.mySnippets.tailnet.name;
in
{
  imports = [
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.btrfs-helium-01
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "helium-01";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  environment.systemPackages = with pkgs; [
    ntfs3g
    jdk21_headless
  ];

  # homestead server w mickey
  networking.firewall.allowedTCPPorts = [ 25565 ];

  myNixOS = {
    base.enable = true;
    profiles.btrfs.enable = true;
    programs = {
      # neovim.enable = true;
      nix.enable = true;
      podman.enable = true;
      systemd-boot.enable = true;
    };
    services = {
      backups = {
        client = {
          enable = true;
          extraExcludes = [
            "/var/cache/immich"
            "/var/lib/prometheus"
            "/var/lib/loki"
            "/var/lib/gitea-actions-runner"
            "/var/lib/caddy"
            "/mnt/hdd/borg-repos"
          ];
          repositories = {
            helium = {
              path = "/mnt/hdd/borg-repos/helium-01";
              label = "helium";
            };
            rsync = {
              path = "ssh://de4388@de4388.rsync.net/./borg-repos/helium-01";
              label = "rsync";
              remotePath = "borg14";
            };
          };
        };
        server = {
          enable = true;
          authorizedKeys = {
            argon = builtins.readFile "${self.inputs.secrets}/borg/argon/borg_ssh_key.pub";
            uranium = builtins.readFile "${self.inputs.secrets}/borg/uranium/borg_ssh_key.pub";
            tungsten = builtins.readFile "${self.inputs.secrets}/borg/tungsten/borg_ssh_key.pub";
            carbon = builtins.readFile "${self.inputs.secrets}/borg/carbon/borg_ssh_key.pub";
          };
        };
      };
      caddy.enable = true;
      copyparty.enable = true;
      fail2ban = {
        enable = true;
        enableCaddyJail = true;
      };
      grafana = {
        enable = true;
        prometheusTargets = map (ip: "${ip}:${toString net.nodeExporter.port}") [
          "localhost"
          net.tailscaleIPs.uranium
          net.tailscaleIPs.tungsten
          net.tailscaleIPs.carbon
          net.tailscaleIPs.argon
        ];
      };
      loki = {
        enable = true;
        listenAddress = "100.64.1.0";
      };
      node-exporter.enable = true;
      smartctl-exporter = {
        enable = true;
        devices = [ "/dev/disk/by-id/usb-WD_My_Book_25ED_575835324443304A30443532-0:0" ];
      };
      promtail = {
        enable = true;
        lokiUrl = "http://localhost:${toString net.loki.port}";
      };
      forgejo-runner = {
        enable = true;
        dockerContainers = 3;
        nativeRunners = 2;
      };
      immich.enable = true;
      paperless-ngx.enable = true;
      tailscale = {
        enable = true;
        operator = "taxborn";
      };
    };
  };

  services.caddy.virtualHosts = {
    "grafana.${tailnet}".extraConfig = ''
      bind tailscale/grafana
      reverse_proxy localhost:${toString net.grafana.port}
    '';
    "immich.${tailnet}".extraConfig = ''
      bind tailscale/immich
      reverse_proxy localhost:${toString net.immich.port}
    '';
    "paperless.${tailnet}".extraConfig = ''
      bind tailscale/paperless
      reverse_proxy localhost:${toString net.paperless.port}
    '';
    "copyparty.${tailnet}".extraConfig = ''
      bind tailscale/copyparty
      reverse_proxy localhost:${toString net.copyparty.port}
    '';
  };

  myHardware = {
    intel.cpu.enable = true;
    profiles.ssd.enable = true;
  };

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];

  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-id/usb-WD_My_Book_25ED_575835324443304A30443532-0:0-part1";
    fsType = "ntfs-3g";
    options = [
      "defaults"
      "nofail"
      "user"
      "exec"
      "uid=1000"
      "gid=100"
      "umask=0000"
      "locale=en_US.utf8"
    ];
  };

  # Ensure the mount point directory exists
  systemd.tmpfiles.rules = [
    "d /mnt/hdd 0755 root root -"
  ];
}
