{ self, ... }:

{
  imports = [
    ./desktop
    ./profiles
    ./programs
    ./services
    ./taxborn
    self.inputs.snippets.homeModules.snippets
    self.inputs.tgirlpkgs.homeModules.default
    self.inputs.zen-browser.homeModules.beta
  ];
}
