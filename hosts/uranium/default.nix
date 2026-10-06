{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
  ];

  home-manager.users.taxborn = {
    home.packages = with pkgs; [
      via
      prismlauncher
    ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
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

  # Large closures (games, toolchains) build here. Start collecting at 5 GiB
  # free and stop at 20 GiB rather than stalling mid-build on a full store.
  nix.settings = {
    min-free = 5 * 1024 * 1024 * 1024;
    max-free = 20 * 1024 * 1024 * 1024;
  };

  boot = {
    # Make accelerated AES available when stage 1 opens cryptroot. dm-crypt
    # allocates its cipher then; loading a faster implementation after opening
    # the mapping does not replace that cipher. A missing initrd module can
    # therefore leave a working root filesystem on a slower implementation.
    initrd.availableKernelModules = [ "aesni_intel" ];
    kernelParams = [
      "intel_iommu=on"
      # Nothing here is passed through to a VM, so devices need no translation.
      # Identity-map them and keep the IOMMU for isolation without paying for
      # DMA remapping on every transfer.
      "iommu=pt"
      # A desktop on mains power. Autosuspend is what makes the MX Master
      # receiver, the QMK board and the YubiKey drop and re-enumerate. Costs
      # battery, so not set on the laptop.
      "usbcore.autosuspend=-1"
    ];
  };

  myNixOS = {
    profiles.workstation.enable = true;
    programs.lanzaboote.enable = true;

    profiles.btrfs.snapshotSubvolumes.compatdata = "/games/steamapps/compatdata";

    services.backups.client = {
      enable = true;
      notify.enable = true;
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

  # With intel_pstate in active HWP mode, powersave still permits the full
  # frequency range. Set the performance hint for this desktop without using
  # the performance governor, which restricts HWP to the highest allowed
  # P-state. These are separate controls despite sharing the word performance.
  # https://docs.kernel.org/admin-guide/pm/intel_pstate.html#active-mode-with-hwp
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
