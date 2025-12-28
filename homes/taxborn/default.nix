{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    self.homeModules.default
  ];

  config = {
    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";
    };

    programs = {
      home-manager.enable = true;
    };

    packages = with pkgs; [
      obsidian
    ];
  };
}
