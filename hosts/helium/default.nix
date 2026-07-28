{ pkgs, self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-helium
  ];

  networking.hostName = "helium";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.server.enable = true;
    programs.systemd-boot.enable = true;

    # Off here alone. This host's whole job is holding the second copy of every
    # other host's archives, and the forced `borg serve --restrict-to-path`
    # command that confines each client is enforced by sshd — which Tailscale
    # SSH bypasses entirely on port 22. Leaving it on would mean any client that
    # gets compromised could open a shell here and delete every repository,
    # which is the exact scenario the restriction exists to prevent.
    #
    # Consequence: reaching Helium needs a real SSH key (`keys/yubikey.pub`,
    # already in its authorized_keys). Tailnet identity is no longer enough.
    services.tailscale.enableSSH = false;
    services.backups = {
      client.enable = true;
      # Helium holds the second copy of every host's archives on its external
      # drive, served over restricted SSH on the tailnet. Its own repository is
      # local, so it needs no key here.
      server = {
        enable = true;
        authorizedKeys = {
          argon = builtins.readFile "${self}/secrets/borg/argon/ssh_key.pub";
          carbon = builtins.readFile "${self}/secrets/borg/carbon/ssh_key.pub";
        };
      };
    };
  };

  myHardware.intel.cpu.enable = true;
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];

  environment.systemPackages = with pkgs; [
    ntfs3g
  ];

  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-id/usb-WD_My_Book_25ED_575835324443304A30443532-0:0-part1";
    fsType = "ntfs-3g";
    # ntfs3g ships no fsck.ntfs helper, so skip the fsck pass
    noCheck = true;
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
