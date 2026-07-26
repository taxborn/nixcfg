{ pkgs, self, ... }:
{
  imports = [
    self.homeModules.default
    self.homeModules.snippets
  ];

  config = {
    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";
      sessionPath = [ "$HOME/.local/bin" ];
      packages = with pkgs; [ just ];
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

    myHome.programs = {
      ssh.enable = true;
    };
  };
}
