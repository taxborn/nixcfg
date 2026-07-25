{ self, ... }:
{
  config = {
    home-manager.users.taxborn.imports = [ self.homeModules.profile-default ];
  };
}
