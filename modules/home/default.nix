{ self, ... }:

{
  imports = [
    ./desktop
    ./profiles
    ./programs
    ./services
    self.inputs.snippets.homeModules.snippets
    self.inputs.zen-browser.homeModules.beta
  ];
}
