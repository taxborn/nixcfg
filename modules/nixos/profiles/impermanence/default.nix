{ config, lib, pkgs, ... }:
let
  cfg = config.myNixOS.profiles.impermanence;

  baseDirectories = [
    "/etc/ssh"
    "/var/lib/nixos"
    "/var/lib/systemd"
    "/var/lib/tailscale"
    "/var/lib/fail2ban"
    "/var/log"
    "/home/taxborn"
  ];

  # Full store paths so the binary is available in the initrd closure.
  # Pure-bash field splitting avoids depending on `cut` in the initrd.
  rollbackScript = pkgs.writeShellScript "rollback-root" ''
    mkdir -p /mnt
    mount -o subvol=/ /dev/disk/by-label/nixos /mnt
    ${pkgs.btrfs-progs}/bin/btrfs subvolume list -o /mnt/root |
      while read -r _ _ _ _ _ _ _ _ subvolume; do
        echo "deleting /$subvolume subvolume..."
        ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "/mnt/$subvolume"
      done
    echo "deleting /root subvolume..."
    ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /mnt/root
    echo "restoring blank /root subvolume..."
    ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot /mnt/blank /mnt/root
    umount /mnt
  '';
in
{
  options.myNixOS.profiles.impermanence = {
    enable = lib.mkEnableOption "impermanence via btrfs blank-snapshot rollback";
    extraDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host-specific directories to persist beyond the fleet base set.";
    };
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/persist".neededForBoot = true;

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = baseDirectories ++ cfg.extraDirectories;
      files = [ "/etc/machine-id" ];
    };

    # btrfs-progs must be present in the initrd for the rollback service.
    boot.initrd.supportedFilesystems = [ "btrfs" ];
    boot.initrd.systemd.storePaths = [ pkgs.btrfs-progs ];

    # Roll back / to the blank snapshot on every boot.
    # Runs before sysroot.mount (which mounts the /root subvol as the new root),
    # so the fresh snapshot is what gets pivoted into.
    boot.initrd.systemd.services.rollback = {
      description = "Roll back btrfs root subvolume to blank snapshot";
      wantedBy = [ "initrd.target" ];
      before = [ "sysroot.mount" ];
      after = [ "local-fs-pre.target" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = rollbackScript;
      };
    };
  };
}
