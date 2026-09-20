{ self, pkgs, ... }:
{
  imports = [
    self.homeModules.default
    self.homeModules.snippets
  ];

  config = {
    home.packages = with pkgs; [
      jdk17_headless
    ];
  };
}
