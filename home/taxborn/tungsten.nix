{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.zen-browser.homeModules.beta

    ../gpg
  ];

  programs.zen-browser.enable = true;
  home.username = "taxborn";
  home.homeDirectory = "/home/taxborn";
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "/home/taxborn/Media/Photos/Wallpapers/mandelbrot_gap_magenta.png" ];
      wallpaper = [ ",/home/taxborn/Media/Photos/Wallpapers/mandelbrot_gap_magenta.png" ];
    };
  };

  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };

  programs.zed-editor = {
    enable = true;
    extensions = [ "nix" ];
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ./waybar.css;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        modules-left = ["hyprland/workspaces"];
        modules-center = ["clock"];
        modules-right = [
          "pulseaudio"
          # "backlight"
          # "battery"
          "network"
          "cpu"
          "memory"
          "tray"
        ];

        "hyprland/workspaces" = {
          format = "{name}: {icon}";
          format-icons = {
            active = "";
            default = "";
          };
        };

        tray = {
          icon-size = 16;
          spacing = 10;
        };

        "custom/music" = {
          format = "  {}";
          escape = true;
          interval = 5;
          tooltip = false;
          exec = "playerctl metadata --format='{{ artist }} - {{ title }}'";
          on-click = "playerctl play-pause";
          max-length = 50;
        };

        clock = {
          timezone = "America/Chicago";
          tooltip-format = "{:%Y-%m-%dT%H:%M:%S%z}";
          format = "{:%Y/%m/%d - %H:%M:%S}";
          interval = 1;
        };

        network = {
          format-wifi = "󰤢";
          format-ethernet = "󰈀";
          format-disconnected = "󰤠";
          interval = 5;
          tooltip = false;
        };

        cpu = {
          interval = 1;
          format = "  {icon0}{icon1}{icon2}{icon3} {usage:>2}%";
          format-icons = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
        };

        memory = {
          interval = 30;
          format = "  {used:0.1f}G/{total:0.1f}G";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "";
          format-icons = {
            default = ["" "" " "];
          };
          on-click = "pavucontrol";
        };
      };
    };
  };

  home.packages = with pkgs; [
    neofetch

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processor https://github.com/mikefarah/yq
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc # it is a calculator for the IPv4/v6 addresses

    # misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    # productivity
    hugo # static site generator
    glow # markdown previewer in terminal

    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
  ];

  programs.git = {
    enable = true;
    userName = "Braxton Fair";
    userEmail = "hello@taxborn.com";

    lfs.enable = true;

    signing.key = "F22AFD6CFD66B874";
    signing.signByDefault = true;
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin"

      export GPG_TTY=$(tty)
      export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
      gpgconf --launch gpg-agent
      gpg-connect-agent updatestartuptty /bye > /dev/null
    '';
    shellAliases = {
      nix-rb = "sudo nixos-rebuild switch --flake /home/taxborn/dotfiles"; # TODO: I think there is an env variable to set the dir
      yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
    };
  };

  home.stateVersion = "25.05";
}
