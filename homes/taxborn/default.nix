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
      homeDirectory = lib.mkForce "/home/taxborn"; # TODO: i dont wanna force this
      stateVersion = "25.11";

      packages = with pkgs; [
        obsidian
      ];
    };

    programs = {
      home-manager.enable = true;
    };
  };
}
