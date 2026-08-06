{
  self,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    self.diskoConfigurations.btrfs-luks-raid1-uranium
  ];

  home-manager.users.taxborn = {
    home.packages = with pkgs; [
      via
      prismlauncher
    ];

    # Desktop: nothing under /sys/class/leds is a kbd_backlight, so the dim
    # listener would fail brightnessctl on every idle cycle.
    myHome.services.hypridle.kbdBacklight = false;
  };

  networking.hostName = "uranium";
  system.stateVersion = "25.11";

  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
    gamemode.enable = true;
  };

  services = {
    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };
  };

  boot = {
    initrd.availableKernelModules = [ "aesni_intel" ];
    kernelParams = [ "intel_iommu=on" ];
  };

  myNixOS = {
    profiles.workstation.enable = true;
    programs.lanzaboote.enable = true;

    profiles.btrfs.snapshotSubvolumes.compatdata = "/games/steamapps/compatdata";

    services.backups.client = {
      enable = true;
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
    "d /games 0755 taxborn users -"
    "d /games/steamapps 0755 taxborn users -"
    "d /games/steamapps/compatdata 0755 taxborn users -"
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

  myHardware = {
    amd.gpu.enable = true;
    intel.cpu.enable = true;
  };

  hardware.steam-hardware.enable = true;
}
