{
  lib,
  self,
  ...
}:
{
  home-manager.users.taxborn = {
    imports = [
      self.homeModules.profile-workstation
    ];

    myHome.programs.minecraft.enable = lib.mkForce false;
  };
}
