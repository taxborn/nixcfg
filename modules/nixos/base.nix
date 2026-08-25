{
  config,
  lib,
  pkgs,
  self,
  ...
}:

{
  options.myNixOS.base.enable = lib.mkEnableOption "base NixOS system configuration";

  config = lib.mkIf config.myNixOS.base.enable {
    home-manager.users.taxborn.imports = [ self.homeModules.profile-default ];

    age.identityPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];

    networking.networkmanager.enable = true;

    catppuccin = {
      accent = "mauve";
      autoEnable = true;
      cache.enable = true;
      enable = true;
      flavor = "mocha";
    };

    myNixOS = {
      profiles = {
        btrfs.enable = true;
        swap.enable = true;
      };
      programs = {
        nix.enable = true;
        ssh.enable = true;
      };
      services = {
        tailscale.enable = true;
        monitoring.client.enable = lib.mkDefault true;
      };
    };

    services = {
      fstrim = {
        enable = true;
        interval = "monthly";
      };
      smartd = {
        enable = lib.mkDefault true;
        autodetect = true;
      };
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
    };

    # nsncd is ordered `Before=nss-lookup.target nss-user-lookup.target`, and
    # both targets are restarted several times during boot as units that want
    # them are pulled in. Each restart drags nscd through a stop/start cycle —
    # four of them inside five seconds on uranium — which is enough to hit
    # systemd's default rate limit of five starts in ten seconds. The unit then
    # latches failed with `start-limit-hit` and stays there: name service
    # caching is gone for the rest of the boot, and it takes nss-lookup.target
    # and nss-user-lookup.target down with it on the way.
    #
    # Nothing about that is loud. The dependency failure is logged once, at
    # boot, and never again, and `Restart=always` cannot recover a unit systemd
    # has stopped issuing start jobs for.
    #
    # Same fix as the tailnet-bound units in services/monitoring/default.nix,
    # for a different cause: there the restarts are a lost address race, here
    # they are ordinary target churn. In both cases the restarts are legitimate
    # and the rate limit is the only thing turning them into a dead unit.
    systemd.services.nscd.unitConfig.StartLimitIntervalSec = 0;

    environment = {
      etc."nixos".source = self;
      systemPackages = with pkgs; [
        self.inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        btop
        wget
        git
        vim
      ];
    };

    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    time.timeZone = lib.mkDefault "America/Chicago";
    system.configurationRevision = self.rev or self.dirtyRev or null;
    hardware.enableRedistributableFirmware = lib.mkDefault true;
  };
}
