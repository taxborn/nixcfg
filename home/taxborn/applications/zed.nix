{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nil
  ];

  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "html"
      "toml"
      "sql"
      "make"
      "lua"
      "zig"
      "csv"
      "env"
      "catppuccin"
    ];
    userSettings = {
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
      auto_indent_on_paste = true;

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
    };
  };
}
