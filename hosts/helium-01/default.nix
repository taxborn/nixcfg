{ self, pkgs, ... }:
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
      nix.enable = true;
      podman.enable = true;
      systemd-boot.enable = true;
    };
    services = {
      backups = {
        enable = true;
        repository = "ssh://de4388@de4388.rsync.net/./borg-repos/helium-01";
      };
      caddy.enable = true;
      copyparty.enable = true;
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
      "umask=0022"
      "locale=en_US.utf8"
    ];
  };

  # Ensure the mount point directory exists
  systemd.tmpfiles.rules = [
    "d /mnt/hdd 0755 root root -"
  ];
}
