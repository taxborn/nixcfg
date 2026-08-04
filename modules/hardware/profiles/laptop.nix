{
  config,
  lib,
  ...
}:
{
  options.myHardware.profiles.laptop.enable = lib.mkEnableOption "Laptop hardware configuration.";

  config = lib.mkMerge [
    (lib.mkIf config.myHardware.profiles.laptop.enable {
      services = {
        # Thunderbolt ships at security level `user`, meaning devices stay
        # unauthorized until something grants it. Nothing does without boltd, so
        # a dock plugged into a machine that lacks it is simply inert.
        hardware.bolt.enable = true;

        # The reader in Tungsten's power button is a Goodix 27c6:63ac, which
        # upstream libfprint already drives through goodixmoc — no TOD shim and
        # no vendor blob. Left unconditional because the daemon is D-Bus
        # activated and simply finds no device on a laptop without a reader.
        #
        # This cannot reach the disk. LUKS is unlocked from the initrd, where
        # fprintd does not exist; the FIDO2 YubiKey remains the only key to the
        # root filesystem. What follows is for prompts on an already-running
        # system.
        fprintd.enable = true;

        tuned.enable = lib.mkDefault true;
        upower.enable = true;
      };

      # `fprintAuth` defaults to `services.fprintd.enable`, and that default
      # lands on every PAM service the host defines — 27 of them here, sshd
      # among them. A finger cannot be presented down an ssh connection, so
      # there the module is pure latency on the auth path. Everywhere else is a
      # local prompt, which is exactly where offering the reader is the point,
      # so the default is left alone rather than enumerated.
      security.pam.services.sshd.fprintAuth = false;

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
            # Remember to define nvidiaBusId and intelBusId/amdBusId in config.hardware.nvidia.prime.
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
