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
      myHome.services.hypridle.hyprlockScale = 2;
    };
  };
}
