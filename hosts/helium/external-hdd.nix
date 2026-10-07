_: {
  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-id/usb-WD_My_Book_25ED_575835324443304A30443532-0:0-part1";
    fsType = "btrfs";
    options = [
      "defaults"
      "nofail"
      "noatime"
      # USB-attached spinning rust does not implement FITRIM, and fstrim exits
      # 64 on the EREMOTEIO. It has already trimmed every other filesystem by
      # then, so nothing goes untrimmed and the unit fails anyway. That is what
      # kept fstrim.service permanently red here.
      "X-fstrim.notrim"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/hdd 0755 root root -"
  ];
}
