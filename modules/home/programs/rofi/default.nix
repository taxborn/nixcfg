{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.formats.rasi) mkLiteral;
  defaultApps.terminal =
    config.myHome.profiles.defaultApps.terminal.exec or (lib.getExe pkgs.ghostty);
in
{
  options.myHome.programs.rofi.enable = lib.mkEnableOption "rofi application launcher";

  config = lib.mkIf config.myHome.programs.rofi.enable {
    programs.rofi = {
      enable = true;
      location = "center";
      package = pkgs.rofi;

      plugins = [
        pkgs.rofi-power-menu
      ];

      inherit (defaultApps) terminal;

      # Taken from https://github.com/Murzchnvok/rofi-collection
      # Adapted from the gnomio theme
      theme = {
        "*" = {
          border = 0;
          margin = 0;
          padding = 0;
          spacing = 0;

          bg0 = mkLiteral "#1e1e2e";
          fg0 = mkLiteral "#cdd6f4";
          fg1 = mkLiteral "#a6adc8";

          purple = mkLiteral "#cba6f7";

          background-color = mkLiteral "var(bg0)";
        };

        window = {
          location = mkLiteral "north";
          width = mkLiteral "35em";
          border = mkLiteral "0 2px 2px 2px";
          border-color = mkLiteral "var(purple)";
          border-radius = mkLiteral "0 0 10px 10px";
        };

        mainbox = {
          padding = mkLiteral "10px";
          children = mkLiteral "[inputbar, listview]";
        };

        entry = {
          padding = mkLiteral "10px";
          text-color = mkLiteral "var(fg0)";
        };

        listview.lines = 10;

        configuration = {
          show-icons = true;
          font = mkLiteral "env(ROFI_FONT, \"JetBrainsMono Nerd Font Medium 12\")";
          display-drun = mkLiteral "\"\"";
          display-run = mkLiteral "\"\"";
          display-window = mkLiteral "\"\"";
        };

        inputbar = {
          children = mkLiteral "[prompt, entry]";
          border = mkLiteral "2px";
          border-color = mkLiteral "var(purple)";
          border-radius = mkLiteral "10px";
          margin = mkLiteral "0 0 10px 0";
        };

        prompt = {
          padding = mkLiteral "10px";
          text-color = mkLiteral "var(fg0)";
        };

        element = {
          children = mkLiteral "[element-icon, element-text]";
          border-radius = mkLiteral "10px";
          border = mkLiteral "2px";
          padding = mkLiteral "10px";
        };

        "element selected" = {
          border = mkLiteral "2px";
          border-color = mkLiteral "var(purple)";
        };

        element-icon = {
          padding = mkLiteral "0 10px 0 0";
          size = mkLiteral "18px";
        };

        element-text.text-color = mkLiteral "var(fg1)";

        "element-text selected".text-color = mkLiteral "var(fg0)";
      };
    };
  };
}
