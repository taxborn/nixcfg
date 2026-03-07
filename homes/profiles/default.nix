{
  config,
  self,
  ...
}:
{
  imports = [
    self.homeModules.default
  ];

  config = {
    nix = {
      inherit (config.mySnippets.nix) settings;

      gc = {
        automatic = true;
        options = "--delete-older-than 3d";
        persistent = true;
        randomizedDelaySec = "60min";
      };
    };

    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";
    };

    programs = {
      home-manager.enable = true;
      fish.enable = true;
    };

    myHome.taxborn.programs = {
      git.enable = true;
      gpg.enable = true;
      tmux.enable = true;
      yubikey.enable = true;
    };
  };
}
