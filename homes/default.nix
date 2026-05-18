{ self, ... }:
{
  imports = [
    self.homeModules.default
  ];

  config = {
    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";
      sessionPath = [ "$HOME/.local/bin" ];
    };

    programs = {
      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting # Disable greeting
        '';
      };
      home-manager.enable = true;
    };

    programs.neovim.enable = true;

    myHome.programs = {
      git.enable = true;
      gpg.enable = true;
      ssh.enable = true;
      yubikey.enable = true;
    };
  };
}
