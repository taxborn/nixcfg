{
  config,
  lib,
  ...
}:
{
  config = lib.mkMerge [
    {
      services = {
        hardware.bolt.enable = true;

        tuned.enable = lib.mkDefault true;
        upower = {
          enable = true;
          criticalPowerAction = "PowerOff";
        };
      };

      boot.extraModprobeConfig = ''
        options iwlwifi power_save=1
      '';

      # Not borgmatic: a skipped unit counts as a success and the timer never retries.
      systemd.services = {
        nix-gc = lib.mkIf config.nix.gc.automatic { unitConfig.ConditionACPower = true; };
        nix-optimise = lib.mkIf config.nix.optimise.automatic {
          unitConfig.ConditionACPower = true;
        };
      };
    }

    {
      services.thermald.enable = true;
    }

    {
      hardware.nvidia = {
        dynamicBoost.enable = lib.mkDefault true;

        powerManagement = {
          enable = true;
          finegrained = true;
        };

        prime.offload = {
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
  ];
}
