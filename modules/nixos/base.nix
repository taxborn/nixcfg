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

    programs.ssh.knownHosts = config.mySnippets.ssh.knownHosts;

    myNixOS = {
      profiles.btrfs.enable = true;
      profiles.swap.enable = true;
      programs.nix.enable = true;
      services.tailscale.enable = true;
    };

    services = {
      fstrim.enable = true;

      # autoScrub checks the filesystem and mdadmConf watches the array, but
      # both report damage that has already happened — SMART is the part that
      # says a drive is on its way out beforehand. `mkDefault` so the OVH
      # profile can turn it off: there is no SMART behind virtio, and smartd
      # fails to start rather than idling when it can register nothing.
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

    environment = {
      etc."nixos".source = self;
      systemPackages = with pkgs; [
        self.inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        btop
        wget
        git
        tmux
        neovim
      ];
    };

    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    time.timeZone = lib.mkDefault "America/Chicago";
    system.configurationRevision = self.rev or self.dirtyRev or null;
    hardware.enableRedistributableFirmware = lib.mkDefault true;
  };
}
