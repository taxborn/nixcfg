{
  pkgs,
  lib,
  config,
  ...
}:
{
  options.myHome.taxborn.programs.tmux.enable = lib.mkEnableOption "enable tmux";

  config = lib.mkIf config.myHome.taxborn.programs.tmux.enable {
    programs.tmux = {
      enable = true;
      mouse = true;
      prefix = "C-a";
      baseIndex = 1;
      escapeTime = 0;
      keyMode = "vi";

      extraConfig = ''
        # C-b is used by vim, C-a is free!
        unbind C-b
        bind C-a send-prefix

        # Vim style pane selection
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Start windows and panes at 1, not 0
        set -g pane-base-index 1
        set-window-option -g pane-base-index 1
        set-option -g renumber-windows on

        bind '"' split-window -v -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"


        set -g set-clipboard on
        set -g allow-passthrough on
      '';

      plugins = with pkgs.tmuxPlugins; [
        sensible
        catppuccin
        vim-tmux-navigator
      ];
    };
  };
}
