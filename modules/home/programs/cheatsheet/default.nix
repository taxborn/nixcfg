{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myHome.programs.cheatsheet;

  entryType = lib.types.submodule {
    options = {
      key = lib.mkOption {
        type = lib.types.str;
        description = "The keybind (e.g. 'Ctrl+p').";
      };
      description = lib.mkOption {
        type = lib.types.str;
        description = "What the keybind does.";
      };
    };
  };

  defaultEntries = {
    hyprland = [
      {
        key = "Super+Return";
        description = "Open terminal";
      }
      {
        key = "Super+B";
        description = "Open browser";
      }
      {
        key = "Super+E";
        description = "Open editor";
      }
      {
        key = "Super+F";
        description = "Open file manager";
      }
      {
        key = "Super+Q";
        description = "Close window";
      }
      {
        key = "Super+Shift+W";
        description = "Fullscreen";
      }
      {
        key = "Super+Shift+V";
        description = "Toggle floating";
      }
      {
        key = "Super+Shift+\\";
        description = "Toggle split";
      }
      {
        key = "Super+H/J/K/L";
        description = "Move focus";
      }
      {
        key = "Super+Shift+H/J/K/L";
        description = "Move window";
      }
      {
        key = "Super+1-9";
        description = "Switch workspace";
      }
      {
        key = "Super+Shift+1-9";
        description = "Move window to workspace";
      }
      {
        key = "Super+Shift+{, OR .}";
        description = "Move window to workspace and move to workspace";
      }
      {
        key = "Super+S";
        description = "Toggle special workspace";
      }
      {
        key = "Super+Shift+S";
        description = "Move to special workspace";
      }
      {
        key = "Super+L";
        description = "Lock session";
      }
      {
        key = "Ctrl+F12";
        description = "Screenshot Area";
      }
      {
        key = "Super+Shift+E";
        description = "Emoji picker";
      }
      {
        key = "Super+Shift+R";
        description = "Bitwarden (rofi-rbw)";
      }
    ];
    neovim = [
      {
        key = "i / a / o";
        description = "Enter insert mode (at cursor / after / new line below)";
      }
      {
        key = "Esc";
        description = "Return to normal mode";
      }
      {
        key = "v / V / Ctrl+v";
        description = "Visual mode (char / line / block)";
      }
      {
        key = "w / b / e";
        description = "Next word / prev word / end of word";
      }
      {
        key = "0 / $ / ^";
        description = "Start / end / first non-blank of line";
      }
      {
        key = "gg / G";
        description = "Go to top / bottom of file";
      }
      {
        key = "Ctrl+d / Ctrl+u";
        description = "Scroll half page down / up";
      }
      {
        key = "dd / yy / p";
        description = "Delete line / yank line / paste";
      }
      {
        key = "u / Ctrl+r";
        description = "Undo / redo";
      }
      {
        key = "/ / n / N";
        description = "Search / next match / prev match";
      }
      {
        key = ":%s/old/new/g";
        description = "Search and replace (whole file)";
      }
      {
        key = ":w / :q / :wq";
        description = "Save / quit / save and quit";
      }
      {
        key = "Ctrl+w s / Ctrl+w v";
        description = "Split horizontal / vertical";
      }
      {
        key = "Ctrl+w h/j/k/l";
        description = "Navigate splits";
      }
      {
        key = ">> / <<";
        description = "Indent / dedent line";
      }
      {
        key = "ci\" / di( / ya{";
        description = "Change/delete/yank inside delimiters";
      }
      {
        key = ". (dot)";
        description = "Repeat last change";
      }
    ];
    tmux = [
      # The tmux command is Ctrl+a instead of the default Ctrl+b
      {
        key = "Ctrl+a d";
        description = "Detach session";
      }
      {
        key = "Ctrl+a c";
        description = "New window";
      }
      {
        key = "Ctrl+a n / p";
        description = "Next / previous window";
      }
      {
        key = "Ctrl+a 0-9";
        description = "Switch to window by number";
      }
      {
        key = "Ctrl+a ,";
        description = "Rename window";
      }
      {
        key = "Ctrl+a &";
        description = "Kill window";
      }
      {
        key = "Ctrl+a %";
        description = "Split pane vertical";
      }
      {
        key = "Ctrl+a \"";
        description = "Split pane horizontal";
      }
      {
        key = "Ctrl+a arrow";
        description = "Navigate panes";
      }
      {
        key = "Ctrl+a x";
        description = "Kill pane";
      }
      {
        key = "Ctrl+a z";
        description = "Toggle pane zoom";
      }
      {
        key = "Ctrl+a [";
        description = "Enter copy mode";
      }
      {
        key = "Ctrl+a s";
        description = "List sessions";
      }
      {
        key = "Ctrl+a $";
        description = "Rename session";
      }
      {
        key = "Ctrl+a w";
        description = "Session/window tree";
      }
      {
        key = "Ctrl+a ?";
        description = "List keybindings";
      }
    ];
  };

  cheatsheetText = lib.concatStringsSep "\n" (
    lib.concatLists (
      lib.mapAttrsToList (
        category: entries:
        builtins.map (entry: "[${category}]  ${entry.key}  --  ${entry.description}") entries
      ) cfg.entries
    )
  );

  cheatsheetFile = pkgs.writeText "cheatsheet.txt" cheatsheetText;

  cheatsheetLauncher = pkgs.writeShellApplication {
    name = "cheatsheet";
    runtimeInputs = [ config.programs.rofi.package ];
    text = ''
      rofi -dmenu -i -p "Keybinds" -no-custom \
        -theme-str 'listview { lines: 20; }' \
        < ${cheatsheetFile} || true
    '';
  };
in
{
  options.myHome.programs.cheatsheet = {
    enable = lib.mkEnableOption "Keybind cheatsheet popup via rofi";

    entries = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf entryType);
      default = defaultEntries;
      description = "Keybind entries grouped by category. Each category maps to a list of { key, description } entries.";
      example = {
        tmux = [
          {
            key = "Ctrl+b d";
            description = "Detach session";
          }
        ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cheatsheetLauncher ];

    wayland.windowManager.hyprland.settings.bind = lib.mkIf config.myHome.desktop.hyprland.enable [
      "CTRL SHIFT,slash,exec,${lib.getExe cheatsheetLauncher}"
    ];
  };
}
