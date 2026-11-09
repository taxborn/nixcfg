{ self, ... }:
{
  imports = [
    self.homeModules.default
    self.homeModules.snippets
  ];
}
