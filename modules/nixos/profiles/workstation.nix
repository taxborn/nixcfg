{
  config,
  lib,
  self,
  pkgs,
  ...
}:
let
  cfg = config.myNixOS.profiles.workstation;
in
{
  options.myNixOS.profiles.workstation.enable = lib.mkEnableOption "workstation configuration";

  config = lib.mkIf cfg.enable {
    home-manager.users.taxborn.imports = [ self.homeModules.profile-workstation ];

    age.identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/home/taxborn/.config/age/yubikey-identity.txt"
    ];

    # `mkDefault` so a host can fall back to an LTS kernel when a new release
    # regresses on its hardware, without reaching for `mkForce`.
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    # The kernel default is `madvise`, so only programs that ask get huge pages.
    # `always` hands them to games and builds without each one opting in, and
    # `defer` keeps the allocator from stalling a frame to compact memory for
    # one. Workstations only. Databases on the servers (Postgres, Redis) do
    # worse with it on.
    boot.kernel.sysfs.kernel.mm.transparent_hugepage = {
      enabled = "always";
      defrag = "defer";
    };

    # A hung unit on a desktop is a shutdown that sits at "a stop job is
    # running" for the default 90 seconds. Nothing on a workstation needs that
    # long to start or stop. Servers keep the default, where a database
    # flushing on stop can legitimately take that long.
    systemd = {
      # Runs shellcheck over every script NixOS generates for a unit, and also
      # makes each one `set -o nounset`. Workstations only. On Helium it broke
      # paperless-scheduler, whose pre-start reads $CREDENTIALS_DIRECTORY, a
      # variable systemd does not set there. Shellcheck cannot see that, so
      # every host built clean and the failure only showed at activation. Do
      # not enable it on a server without reading each generated script.
      enableStrictShellChecks = true;

      settings.Manager = {
        DefaultTimeoutStartSec = "15s";
        DefaultTimeoutStopSec = "15s";
        DefaultTimeoutAbortSec = "15s";
        DefaultDeviceTimeoutSec = "15s";
      };
      user.settings.Manager = {
        DefaultTimeoutStartSec = "15s";
        DefaultTimeoutStopSec = "15s";
        DefaultTimeoutAbortSec = "15s";
        DefaultDeviceTimeoutSec = "15s";
      };
    };

    programs = {
      niri.enable = true;
      noctalia = {
        enable = true;
        recommendedServices.enable = true;
      };
    };

    # Journals on a workstation are for the current boot's debugging, not an
    # audit trail. Servers keep the default, where history matters.
    services.journald.settings.Journal = {
      SystemMaxUse = "100M";
      RuntimeMaxUse = "50M";
      SystemMaxFileSize = "50M";
    };

    # Pulls in a speech dispatcher closure of several hundred MiB that nothing
    # here uses. Browsers keep a minimal copy regardless.
    services.speechd.enable = false;
    programs.nano.enable = false;

    # NixOS ships perl, rsync and strace to every machine by default. Nothing
    # here uses them directly, and anything that needs one pulls it in as a
    # dependency. Add `strace` to the system packages when debugging a hang.
    environment.defaultPackages = [ ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
      atkinson-hyperlegible-next
    ];

    # The NL variant drops JetBrains Mono's ligatures. `NFM` is the Nerd Font
    # Mono family, which keeps glyphs single-width for terminals.
    fonts.fontconfig.defaultFonts = {
      sansSerif = [ "Atkinson Hyperlegible Next" ];
      serif = [ "Atkinson Hyperlegible Next" ];
      monospace = [ "JetBrainsMonoNL NFM" ];
    };

    services = {
      # systemd-oomd (`profiles/swap.nix`) reacts to cgroup memory pressure,
      # which can arrive after the desktop has already stalled on a nix build.
      # earlyoom watches free memory and swap directly and acts before that. The
      # `--avoid` list is the session and the things that cannot be restarted
      # unnoticed. `--prefer` is what is cheap to lose. earlyoom matches the
      # kernel `comm` name, which is truncated to 15 characters, so the patterns
      # are anchored to that rather than the full command line. `-g` kills the
      # whole process group, so a browser goes down with its renderers.
      earlyoom = {
        enable = true;
        enableNotifications = true;
        freeMemThreshold = 5;
        freeMemKillThreshold = 2;
        freeSwapThreshold = 5;
        freeSwapKillThreshold = 2;
        extraArgs = [
          "-g"
          "--avoid"
          "^(niri|noctalia-shell|quickshell|Xwayland|xwayland-satell.*|cryptsetup|dbus-.*|gpg-agent|ssh-agent|sshd|systemd|systemd-.*|ghostty|fish|n?vim)$"
          "--prefer"
          "^(Web Content|Isolated Web Co|firefox.*|chrom(e|ium).*|electron|java.*|.*[.]exe|nix|node|npm)$"
        ];
      };
      # earlyoom turns this on to deliver its notifications, while smartd (see
      # `base.nix`) sets it false. The forwarder is harmless to smartd, which
      # gains desktop notifications from it, so the workstation wins.
      systembus-notify.enable = lib.mkForce true;
      blueman.enable = lib.mkIf config.hardware.bluetooth.enable true;
      fwupd.enable = true;
      gnome.gnome-keyring.enable = true;
      gvfs.enable = true;
      udisks2.enable = true; # Automount for USB drives, which gvfs hands off to.
      libinput.enable = true;

    };

    myHardware.logitech.mx-master.enable = true;

    myNixOS = {
      base.enable = true;
      # Port 22 stays shut on a workstation. The option says why.
      programs.ssh.openFirewall = false;
      profiles = {
        audio.enable = true;
        bluetooth.enable = true;
        btrfs.guiTools = true;
        containers.enable = true;
        graphical-boot.enable = true;
      };
      services.yubikey.enable = true;
    };

    hardware = {
      keyboard.qmk.enable = true;
    };
  };
}
