{ pkgs, ... }:
{
  # imports = [
  #   self.homeModules.default
  # ];

  config = {
    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";
      sessionPath = [ "$HOME/.local/bin" ];
      # packages = with pkgs; [ ];
    };

    programs = {
      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting # Disable greeting
          # ${pkgs.fnm}/bin/fnm env --use-on-cd --shell fish | source
        '';
      };
      home-manager.enable = true;
    };

    # myHome.programs = {
    #   fzf.enable = true;
    #   git.enable = true;
    #   gpg.enable = true;
    #   ssh.enable = true;
    #   tmux.enable = true;
    #   yazi.enable = true;
    # };
  };
}
