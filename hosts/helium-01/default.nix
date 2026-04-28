{
  self,
  pkgs,
  ...
}:
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
  ];

  myNixOS = {
    base.enable = true;
    profiles.btrfs.enable = true;
    programs = {
      nix.enable = true;
      podman.enable = true;
      systemd-boot.enable = true;
    };
    services = {
      backups = {
        client = {
          enable = false;
          enableRsyncRepo = true;
          enableHeliumRepo = true;
          extraExcludes = [
            "/var/lib/caddy"
            "/mnt/hdd/borg-repos"
          ];
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
      fail2ban = {
        enable = true;
        enableCaddyJail = true;
      };
      tailscale = {
        enable = true;
        operator = "taxborn";
      };
    };
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
