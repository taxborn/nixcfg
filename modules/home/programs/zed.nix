{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.zed.enable = lib.mkEnableOption "Zed editor";

  config = lib.mkIf config.myHome.programs.zed.enable {
    programs.zed-editor = {
      enable = true;
      installRemoteServer = true;

      extensions = [
        "astro"
        "catppuccin"
        "catppuccin-icons"
        "html"
        "lua"
        "nix"
        "toml"
        "zig"
      ];

      userSettings = {
        vim_mode = true;
        ui_font_family = "JetBrainsMonoNL NFM";
        ui_font_size = 16.0;
        buffer_font_family = "JetBrainsMonoNL NFM";
        buffer_font_weight = 600.0;
        buffer_font_size = 14.0;
        agent_ui_font_size = 15.0;
        project_panel.dock = "left";

        theme = {
          mode = "dark";
          light = lib.mkDefault "Catppuccin Latte";
          dark = "Catppuccin Mocha";
        };

        icon_theme = lib.mkDefault {
          mode = "dark";
          light = lib.mkDefault "Catppuccin Latte";
          dark = "Catppuccin Mocha";
        };

        wrap_guides = [
          80
          100
        ];

        auto_indent_on_paste = true;
        auto_update = false;
        autosave = "on_focus_change";

        languages = {
          Nix = {
            language_servers = [ "nil" ];
            formatter.external = {
              command = "nixfmt";
              arguments = [ ];
            };
          };
        };

        lsp.nil = {
          binary.path = "nil";
          binary.arguments = [ ];
          settings.nix.flake.autoArchive = true;
        };

        terminal = {
          shell = {
            with_arguments = {
              program = "fish";
              args = [
                "-C"
                "tmux new-session -A -s zed"
              ];
            };
          };
        };

        agent_servers = {
          claude-acp = {
            type = "registry";
            default_config_options = {
              mode = "auto";
            };
          };
        };
      };
    };
  };
}
