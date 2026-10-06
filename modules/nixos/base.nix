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
      };
    };

    services = {
      # Monthly rather than the weekly default. Every btrfs mount in
      # `modules/disko` carries `discard=async` and every LUKS volume allows
      # discards, so extents are trimmed as they are freed and this pass mostly
      # repeats that work. On Tungsten it still spent over two minutes of I/O
      # finding leftovers. Kept rather than dropped because it covers the one
      # thing async discard cannot, which is space the filesystem never
      # allocated in the first place.
      fstrim = {
        enable = true;
        interval = "monthly";
      };
      # Scrub and mdadm report damage that has already happened. SMART is the
      # part that warns beforehand. `mkDefault` so the OVH profile can turn it
      # off, where there is no SMART behind virtio and smartd fails to start
      # rather than idling with nothing to register.
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

    # Runs shellcheck over every script NixOS generates for a unit, so a
    # quoting mistake in an inline script fails the build rather than a boot.
    systemd.enableStrictShellChecks = true;

    boot.kernel.sysctl = {
      # Nothing here replaces a running kernel with kexec, and an attacker with
      # root could use it to load one that skips the module and lockdown checks.
      # One-way until the next boot. nixos-anywhere kexecs into an installer on
      # a target that has no config of ours yet, so provisioning is unaffected.
      "kernel.kexec_load_disabled" = true;

      # Stricter than the NixOS defaults of 1. Hides kernel pointers from root
      # as well, and stops O_CREAT opens of other users' FIFOs and regular
      # files in sticky world-writable directories. A tool that deliberately
      # writes into another user's file in /tmp is the thing that breaks.
      "kernel.kptr_restrict" = 2;
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
    };

    # nsncd is ordered `Before=nss-lookup.target nss-user-lookup.target`, and
    # both targets are restarted several times during boot as units that want
    # them are pulled in. Each restart cycles nscd, four times inside five
    # seconds on uranium, which is enough to trip systemd's default limit of
    # five starts in ten seconds. The unit then latches failed with
    # `start-limit-hit` and takes both targets down with it, so name service
    # caching is gone for the rest of the boot. Nothing about that is loud. It
    # is logged once, at boot, and `Restart=always` cannot recover a unit
    # systemd has stopped issuing start jobs for.
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
