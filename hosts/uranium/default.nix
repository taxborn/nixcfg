{
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    ./amd-gpu.nix
    ./libvirt.nix
    ../../modules/nixos/workstation
    ./disko.nix
  ];

  home-manager.users.${config.homelab.owner.username} = {
    home.packages = with pkgs; [
      via
      prismlauncher
    ];
  };

  # The libvirtd group is root-equivalent, the same trade as wheel.
  users.users.${config.homelab.owner.username}.extraGroups = [ "libvirtd" ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "uranium";
  system.stateVersion = "25.11";

  programs = {
    # No Steam firewall options. Together they opened eight ports to every interface.
    steam.enable = true;
    gamemode.enable = true;
  };

  services = {
    scx-loader = {
      enable = true;
      config.default_sched = "scx_lavd";
    };
  };

  nix.settings = {
    min-free = 5 * 1024 * 1024 * 1024;
    max-free = 20 * 1024 * 1024 * 1024;
  };

  boot = {
    # dm-crypt picks its cipher in stage 1. A faster module loaded later does not replace it.
    initrd.availableKernelModules = [ "aesni_intel" ];
    kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
      "usbcore.autosuspend=-1"
    ];
  };

  homelab = {
    btrfs.snapshotSubvolumes.compatdata = "/games/steamapps/compatdata";

    backups = {
      desktopExcludes = true;
      paths = [
        "/home"
        "/var/lib"
        "/etc"
        "/games/steamapps/compatdata"
      ];
      repositories.local = {
        label = "local";
        path = "/mnt/backup/borg/uranium";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /games 0755 ${config.homelab.owner.username} users -"
    "d /games/steamapps 0755 ${config.homelab.owner.username} users -"
    "d /games/steamapps/compatdata 0755 ${config.homelab.owner.username} users -"
  ];

  systemd.services.cpu-epp = {
    description = "Bias HWP toward performance rather than balance_performance";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for policy in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        echo performance >"$policy"
      done
    '';
  };

  systemd.services.borg-local-repo-base = {
    description = "Create the local borg repository base directory";
    wantedBy = [ "multi-user.target" ];
    before = [ "borgmatic.service" ];
    unitConfig.RequiresMountsFor = "/mnt/backup";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe' pkgs.coreutils "mkdir"} -p /mnt/backup/borg";
    };
  };

  hardware.steam-hardware.enable = true;
}
