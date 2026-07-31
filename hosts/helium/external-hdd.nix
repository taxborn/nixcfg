{ pkgs, ... }:
{
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
