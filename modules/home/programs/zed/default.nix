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
        "catppuccin"
        "catppuccin-icons"
        "html"
        "lua"
        "nix"
      ];
      userSettings = {
        vim_mode = true;
        icon_theme = "Catppuccin Mocha";
        ui_font_family = "JetBrainsMono NFM";
        ui_font_size = 16.0;
        buffer_font_family = "JetBrainsMono NFM";
        buffer_font_weight = 600.0;
        buffer_font_size = 14.0;
        agent_ui_font_size = 15.0;
        project_panel.dock = "left";

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
      };
    };
  };
}
