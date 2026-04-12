{ self, ... }:

{
  imports = [
    ./desktop
    ./profiles
    ./programs
    ./services
    self.inputs.snippets.homeModules.snippets
  ];
}
