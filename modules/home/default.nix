{ self, ... }:

{
  imports = [
    ./desktop
    ./profiles
    ./programs
    ./services
    ./taxborn
    self.inputs.zen-browser.homeModules.beta
  ];
}
