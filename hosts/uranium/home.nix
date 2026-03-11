{
  self,
  ...
}:
{
  home-manager.users.taxborn = {
    imports = [
      self.homeModules.profile-workstation
    ];

    config = {
      myHome = {
        taxborn.programs.minecraft.enable = true;
        programs = {
          obs.enable = true;
          ledger.enable = true;
          via.enable = true;
        };
      };
    };
  };
}
