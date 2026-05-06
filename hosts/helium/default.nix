{
  self,
  pkgs,
  ...
}:
{
  imports = [
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.btrfs-helium
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "helium";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  environment.systemPackages = with pkgs; [
    ntfs3g
  ];

  myNixOS = {
    profiles.serverBase.enable = true;
    services.monitoring.client.enable = true;
    programs.systemd-boot.enable = true;
    services.backups = {
      server.enable = true;
      client.extraExcludes = [
        "/var/lib/caddy"
        "/mnt/hdd/borg-repos"
      ];
    };
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
