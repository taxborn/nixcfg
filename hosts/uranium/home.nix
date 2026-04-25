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
        programs = {
          ledger.enable = true;
          minecraft.enable = true;
          via.enable = true;
        };
      };
    };
  };
}
