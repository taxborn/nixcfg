{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ntfs3g
  ];

  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-id/usb-WD_My_Book_25ED_575835324443304A30443532-0:0-part1";
    fsType = "ntfs3";
    noCheck = true;
    options = [
      "defaults"
      "nofail"
      "user"
      "exec"
      "uid=1000"
      "gid=100"
      "umask=0000"
      "iocharset=utf8"
      # USB-attached spinning rust does not implement FITRIM, and fstrim exits
      # 64 over the EREMOTEIO — after having already trimmed every other
      # filesystem, so nothing actually goes untrimmed and the unit fails
      # anyway. That is what has kept fstrim.service permanently red here.
      "X-fstrim.notrim"
    ];
  };

  # Ensure the mount point directory exists
  systemd.tmpfiles.rules = [
    "d /mnt/hdd 0755 root root -"
  ];
}
