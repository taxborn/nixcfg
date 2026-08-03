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
  };

  networking.hostName = "uranium";
  system.stateVersion = "25.11";

  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    # Raises the governor, renices the game, and pushes amdgpu to its high
    # performance level for as long as a game holds the D-Bus session, then puts
    # all of it back. Steam and prismlauncher both opt in on their own.
    gamemode.enable = true;
  };

  services = {
    # The 13700K is 8 P-cores plus 8 E-cores, and the stock scheduler is willing
    # to migrate a frame-critical thread onto an E-core mid-frame. lavd weighs
    # latency-sensitivity when placing work, which is the case this hybrid split
    # makes worst.
    #
    # sched_ext schedulers are BPF and supervised: if one stalls or misbehaves
    # the kernel ejects it and falls back to the default scheduler on its own,
    # so the failure mode here is the behaviour this host had before.
    scx = {
      enable = true;
      scheduler = "scx_lavd";
    };
  };

  boot = {
    # dm-crypt picks its skcipher when the mapping is created and keeps it for
    # the life of the device. cryptroot is unlocked in stage 1, so without
    # aesni_intel in the initrd it binds generic AES-XTS and stays there —
    # loading the module after switch_root does not rebind it. The companions
    # in /etc/crypttab open in stage 2 and already get the accelerated path.
    initrd.availableKernelModules = [ "aesni_intel" ];

    # VT-d is enabled in firmware, but this kernel is built with
    # CONFIG_INTEL_IOMMU_DEFAULT_ON unset, so the IOMMU stays dormant and
    # /sys/class/iommu is empty until it is asked for by name.
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

  # intel_pstate runs in active mode with HWP here, which leaves the governor
  # reading `powersave`. That is the driver's full-range mode rather than a cap,
  # so it is correct as-is; the knob that actually biases HWP is the
  # energy/performance preference, which defaults to balance_performance.
  #
  # This host is a desktop on wall power, so bias it the rest of the way.
  # Deliberately not `powerManagement.cpuFreqGovernor = "performance"`: under
  # active-mode HWP that raises the frequency floor to maximum and pins clocks
  # there, which is a much larger and more expensive change than moving the
  # preference. Written per-policy because the attribute is per-CPU.
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
