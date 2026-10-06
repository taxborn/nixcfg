{
  config,
  lib,
  ...
}:
{
  options.myHardware.profiles.laptop.enable = lib.mkEnableOption "Laptop hardware configuration";

  config = lib.mkMerge [
    (lib.mkIf config.myHardware.profiles.laptop.enable {
      services = {
        # Thunderbolt ships at security level `user`, meaning devices stay
        # unauthorized until something grants it. Nothing does without boltd, so
        # a dock plugged into a machine that lacks it is simply inert.
        hardware.bolt.enable = true;

        tuned.enable = lib.mkDefault true;
        upower = {
          enable = true;
          # The default is HybridSleep, which writes RAM to swap before
          # suspending. Hibernation is rejected on these machines (`noresume`,
          # swap is zram), so a critical battery would try a resume path that
          # cannot exist. Powering off at 2% is the honest option.
          criticalPowerAction = "PowerOff";
        };
      };

      # Intel's wifi parts ship with power_save=0 and handle runtime PM fine.
      boot.extraModprobeConfig = ''
        options iwlwifi power_save=1
      '';

      # Housekeeping that nothing depends on finishing promptly, so it can wait
      # for a wall socket. Deliberately not extended to borgmatic: a service
      # skipped by a failed condition is recorded as a success and its timer
      # does not retry, so a laptop that mostly runs on battery would stop
      # backing up and say nothing about it.
      systemd.services = {
        nix-gc = lib.mkIf config.nix.gc.automatic { unitConfig.ConditionACPower = true; };
        nix-optimise = lib.mkIf config.nix.optimise.automatic {
          unitConfig.ConditionACPower = true;
        };
      };
    })

    (lib.mkIf
      ((lib.elem "kvm-intel" config.boot.kernelModules) && config.myHardware.profiles.laptop.enable)
      {
        services.thermald.enable = true;
      }
    )

    (lib.mkIf
      (
        (lib.elem "nvidia" config.services.xserver.videoDrivers) && config.myHardware.profiles.laptop.enable
      )
      {
        hardware.nvidia = {
          dynamicBoost.enable = lib.mkDefault true;

          powerManagement = {
            enable = true;
            finegrained = true;
          };

          prime.offload = {
            # The bus IDs are per-machine and live in the host file,
            # hosts/tungsten/default.nix. nixpkgs asserts on PRIME without
            # them rather than guessing.
            enable = true;
            enableOffloadCmd = true;
          };
        };

        specialisation.nvidia-sync.configuration = {
          environment.etc."specialisation".text = "nvidia-sync";

          hardware.nvidia = {
            powerManagement = {
              enable = lib.mkForce false;
              finegrained = lib.mkForce false;
            };

            prime = {
              offload = {
                enable = lib.mkForce false;
                enableOffloadCmd = lib.mkForce false;
              };

              sync.enable = lib.mkForce true;
            };
          };
        };
      }
    )
  ];
}
