{ pkgs, self, ... }:
{
  imports = [
    self.homeModules.default
    self.homeModules.snippets
  ];

  config = {
    home = {
      packages = with pkgs; [
        jdk_headless
      ];
    };
  };
}
