{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./containers.nix
    ./graphical-boot.nix
    ./lanzaboote.nix
    ./mx-master.nix
    ./yubikey.nix
  ];

  home-manager.users.${config.homelab.owner.username}.imports = [ ../../home/workstation.nix ];

  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/home/${config.homelab.owner.username}/.config/age/yubikey-identity.txt"
  ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  boot.kernel.sysfs.kernel.mm.transparent_hugepage = {
    enabled = "always";
    defrag = "defer";
  };

  systemd = {
    # Workstations only. It broke a server unit that only failed at activation.
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

  environment.systemPackages = with pkgs; [
    nil
    nixd
    nixfmt
  ];

  programs = {
    nix-ld.enable = true;
    niri.enable = true;
    noctalia = {
      enable = true;
      recommendedServices.enable = true;
    };
  };

  services.journald.settings.Journal = {
    SystemMaxUse = "100M";
    RuntimeMaxUse = "50M";
    SystemMaxFileSize = "50M";
  };

  services.speechd.enable = false;
  programs.nano.enable = false;

  environment.defaultPackages = [ ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    atkinson-hyperlegible-next
  ];

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Atkinson Hyperlegible Next" ];
    serif = [ "Atkinson Hyperlegible Next" ];
    monospace = [ "JetBrainsMonoNL NFM" ];
  };

  services = {
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
    systembus-notify.enable = lib.mkForce true;
    blueman.enable = true;
    fwupd.enable = true;
    gnome.gnome-keyring.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;
    libinput.enable = true;

  };

  homelab = {
    # Port 22 stays shut on a workstation.
    ssh.openFirewall = false;
    btrfs.guiTools = true;
  };

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
  };

  hardware = {
    bluetooth.enable = true;
    keyboard.qmk.enable = true;
  };
}
