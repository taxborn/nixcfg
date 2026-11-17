{
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
    onShutdown = "shutdown";
  };

  programs.virt-manager.enable = true;

  # Throwaway disks: excluded from backups, and +C drops their checksums.
  systemd.tmpfiles.rules = [
    "d /var/lib/libvirt/images 0711 root root -"
    "h /var/lib/libvirt/images - - - - +C"
    "f /var/lib/libvirt/images/.nobackup 0644 root root -"
  ];
}
