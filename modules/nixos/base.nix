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

    myNixOS = {
      profiles.btrfs.enable = true;
      profiles.swap.enable = true;
      programs.nix.enable = true;
      programs.ssh.enable = true;
      services.tailscale.enable = true;

      # On by default rather than opted into per host, and that is the whole
      # design. The previous version of this stack had the exporters behind a
      # per-host flag while the server scraped every entry in
      # `mySnippets.tailnet.tailscaleIPs` regardless — two lists that agreed only
      # by coincidence, where forgetting the flag on a new host bought a
      # permanently unmonitored machine and forgetting the roster entry bought a
      # target that was down forever. Deriving both from the roster and enabling
      # the client here collapses that to one list: a host on the tailnet is
      # monitored, and there is nothing else to remember.
      #
      # `mkDefault` so a host can still decline, which no host currently does.
      services.monitoring.client.enable = lib.mkDefault true;
    };

    services = {
      # Monthly rather than the weekly default. Every btrfs mount in
      # `modules/disko` carries `discard=async` and every LUKS volume allows
      # discards, so freed extents are already being trimmed continuously and
      # this pass mostly duplicates that — on Tungsten it still spent over two
      # minutes of I/O finding leftovers. Kept rather than dropped because it
      # covers what async discard does not: space the filesystem never
      # allocated in the first place.
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
