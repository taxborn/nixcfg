{
  self,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    ./home.nix
    ./secrets.nix

    self.diskoConfigurations.btrfs-carbon
    self.nixosModules.locale-en-us

    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.caddy = {
    virtualHosts."mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';
  };
  services.caddy = {
    virtualHosts."taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    virtualHosts."www.taxborn.com".extraConfig = ''
      respond "Hello, World!"
    '';

    virtualHosts."braxtonfair.com".extraConfig = ''
      redir https://www.braxtonfair.com{uri} permanent
    '';
    virtualHosts."www.braxtonfair.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
  };

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
      nix.enable = true;
    };
    services = {
      tailscale = {
        enable = true;
        operator = "taxborn";
      };
      backups = {
        enable = true;
        repository = "ssh://de4388@de4388.rsync.net/./borg-repos/carbon";
      };
      glance.enable = true;
      forgejo.enable = true;
      vaultwarden.enable = true;
      caddy.enable = true;
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
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
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
