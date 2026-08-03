{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # The kernel driver below replaces ntfs-3g for mounting, but neither driver
    # ships userspace tooling — this is still what provides `ntfsfix` and
    # `mkntfs`, and `ntfsfix` is what clears the dirty flag described below.
    ntfs3g
  ];

  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-id/usb-WD_My_Book_25ED_575835324443304A30443532-0:0-part1";

    # The in-kernel driver rather than ntfs-3g, which is FUSE and puts every
    # read and write to this 5.5T drive through userspace.
    #
    # The trade is that ntfs3 refuses a volume Windows left dirty, where ntfs-3g
    # would mount it anyway — so a drive last touched by a machine with fast
    # startup enabled will not come up. `nofail` keeps that from being a boot
    # problem, and `ntfsfix -d` on the partition clears the flag.
    fsType = "ntfs3";
    # Neither driver ships an fsck.ntfs helper, so skip the fsck pass
    noCheck = true;
    options = [
      "defaults"
      "nofail"
      "user"
      "exec"
      "uid=1000"
      "gid=100"
      "umask=0000"
      # ntfs3's spelling of what ntfs-3g called `locale`; it does not take that.
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
