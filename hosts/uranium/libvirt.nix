{
  virtualisation.libvirtd = {
    enable = true;
    # Windows 11 refuses to install without a TPM 2.0 device. swtpm emulates
    # one per VM, and libvirt only offers it when this is on.
    qemu.swtpm.enable = true;
    # Stop guests cleanly when the host shuts down, rather than powering
    # them off mid-write. The defaults are `start = none` for boot and
    # `suspend`, which writes each guest's RAM to disk and leaves a large
    # file behind for VMs that were meant to be thrown away.
    onShutdown = "shutdown";
  };

  programs.virt-manager.enable = true;

  # Disposable guests, so their disks are not worth a borg archive. A multi-GiB
  # qcow2 changes on every boot and would dominate the nightly run. The
  # backup module honours this marker (`exclude_if_present`). Move a VM you
  # care about out of this directory, or delete the marker, to back it up.
  #
  # `+C` turns off copy-on-write for the images. A qcow2 on a CoW btrfs
  # filesystem stacks two copy-on-write layers and fragments badly. It also
  # drops checksums for these files, which is acceptable for throwaway disks
  # and not for anything else. The flag only takes effect on an empty
  # directory, so files created before this rule keep CoW.
  systemd.tmpfiles.rules = [
    "d /var/lib/libvirt/images 0711 root root -"
    "h /var/lib/libvirt/images - - - - +C"
    "f /var/lib/libvirt/images/.nobackup 0644 root root -"
  ];
}
