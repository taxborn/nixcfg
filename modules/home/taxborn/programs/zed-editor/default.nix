{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.myHome.taxborn.programs.zed-editor.enable = lib.mkEnableOption "zed editor";

  config = lib.mkIf config.myHome.taxborn.programs.zed-editor.enable {
    home.packages = with pkgs; [
      nil
      nixfmt
    ];

    programs.zed-editor = {
      enable = true;
      installRemoteServer = true;

      userKeymaps = [
        {
          context = "Workspace";

          bindings = {
            cmd-p = "command_palette::Toggle";
            cmd-shift-p = "file_finder::Toggle";
            ctrl-p = "command_palette::Toggle";
            ctrl-shift-p = "file_finder::Toggle";
          };
        }
      ];

      userSettings = {
        auto_indent_on_paste = true;
        auto_update = false;
        disable_ai = true;
        icon_theme = "Catppuccin Mocha";
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

        # --- Appearance ---
        buffer_font_family = "Atkinson Hyperlegible Mono";
        buffer_font_size = 15;
        buffer_font_weight = 400;

        buffer_line_height = "comfortable";
        current_line_highlight = "all";
        selection_highlight = true;
        ui_font_family = "Atkinson Hyperlegible Next";
        ui_font_size = 15;
        ui_font_weight = 400;

        auto_signature_help = true;
        cursor_blink = false;
        hide_mouse = "on_typing_and_movement";
        hover_popover_delay = 350;
        hover_popover_enabled = true;
        middle_click_paste = true;
        show_completion_documentation = true;
        show_completions_on_input = true;
        show_edit_predictions = true;
        show_wrap_guides = true;
        use_autoclose = true;
        use_auto_surround = true;
        vim_mode = true;

        features.edit_prediction_provider = "copilot";
        minimap.show = "auto";
        preferred_line_length = 80;
        soft_wrap = "preferred_line_length";

        use_on_type_format = true;
        wrap_guides = [ 80 ];
      };
    };
  };
}
