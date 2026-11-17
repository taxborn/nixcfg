_: {
  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-id/usb-WD_My_Book_25ED_575835324443304A30443532-0:0-part1";
    fsType = "btrfs";
    options = [
      "defaults"
      "nofail"
      "noatime"
      "X-fstrim.notrim"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/hdd 0755 root root -"
  ];
}
