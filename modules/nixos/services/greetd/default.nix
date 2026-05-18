{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myNixOS.services.greetd;

  swayConfig = lib.optionalString (cfg.primaryOutput != null) (
    pkgs.writeText "greetd-sway-config" ''
      output * disable
      output ${cfg.primaryOutput} enable scale ${toString cfg.outputScale}
      exec "${lib.getExe config.programs.regreet.package}; ${pkgs.sway}/bin/swaymsg exit"
    ''
  );

  sessionCommand =
    if cfg.primaryOutput != null then
      "${pkgs.sway}/bin/sway --config ${swayConfig}"
    else
      "${pkgs.cage}/bin/cage -s -- ${lib.getExe config.programs.regreet.package}";
in
{
  options.myNixOS.services.greetd = {
    enable = lib.mkEnableOption "greetd display manager with ReGreet";

    outputScale = lib.mkOption {
      description = ''
        HiDPI output scale for the greeter. On multi-monitor setups (sway mode)
        this sets the scale of the primary output. On single-monitor cage mode it
        drives WLR_OUTPUT_SCALE, GDK_SCALE, and XCURSOR_SIZE.
      '';
      type = lib.types.ints.positive;
      default = 1;
    };

    primaryOutput = lib.mkOption {
      description = ''
        Wayland output name to show the greeter on (e.g. "DP-3"). When set,
        sway is used as the compositor with all other outputs disabled, which
        fixes greeter spanning across multiple monitors. Leave null for
        single-monitor setups to keep using cage.
      '';
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.regreet = {
      enable = true;
      # Adapted from https://github.com/FaustXVI/nixos-configuration/blob/03f7ca3ce2266351084e58ee3d61994019251053/modules/hardware/regreet.nix#L4
      extraCss =
        let
          palettes = builtins.fromJSON (
            builtins.readFile "${config.catppuccin.sources.palette}/palette.json"
          );
          p = palettes.${config.catppuccin.flavor}.colors;
          defineColors = lib.concatMapStrings (name: "@define-color ${name} ${p.${name}.hex};\n") (
            lib.attrNames p
          );
        in
        ''
          ${defineColors}
          @define-color accent @${config.catppuccin.accent};

          window {
              background: @base;
          }

          selection {
              color: @text;
              background: alpha(@overlay2,0.3);
          }

          frame,
          image,
          grid {
              border:0;
              color: @text;
          }

          frame {
              box-shadow: 0 0 0.5rem @accent;
          }

          button,
          entry,
          combobox,
          combobox entry,
          combobox popover,
          combobox popover contents,
          combobox popover contents modelbutton,
          combobox button,
          combobox window menu,
          frame,
          input {
              color: @text;
              border-color: @surface0;
              background: @surface0;
          }

          button:hover,
          combobox:hover,
          combobox modelbutton:hover{
              border-color: @surface1;
              background: @surface1;
          }


          button.suggested-action{
              color: @base;
              border-color: @accent;
              background: @accent;
          }
          button.suggested-action:hover{
              border-color: darker(@accent);
              background: darker(@accent);
          }

          button.destructive-action{
              color: @base;
              border-color: @red;
              background: @red;
          }
          button.destructive-action:hover{
              border-color: darker(@red);
              background: darker(@red);
          }

          infobar,
          infobar box {
              border: 0;
              background: @surface0;
              color: @red;
          }
        '';
      settings = {
        background = {
          path = "${../../../../assets/wallpapers/island.jpeg}";
          fit = "Cover";
        };
        GTK = {
          font_name = lib.mkForce "JetBrainsMono Nerd Font Mono 14";
        };
        font = {
          name = "JetBrainsMono Nerd Font Mono";
          package = pkgs.nerd-fonts.jetbrains-mono;
          size = 14;
        };
      };
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = sessionCommand;
          user = "greeter";
        };
      };
    };

    systemd.services.greetd.environment = lib.mkIf (cfg.primaryOutput == null) {
      WLR_OUTPUT_SCALE = toString cfg.outputScale;
      GDK_SCALE = toString cfg.outputScale;
      XCURSOR_SIZE = toString (24 * cfg.outputScale);
    };

    # Ensure greeter has access to wayland session desktop files
    environment.etc."greetd/environments".text = ''
      hyprland-uwsm.desktop
    '';
  };
}
