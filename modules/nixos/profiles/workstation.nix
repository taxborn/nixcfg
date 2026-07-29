{
  config,
  lib,
  self,
  ...
}:
{
  options.myNixOS.profiles.workstation.enable = lib.mkEnableOption "workstation configuration";

  config = lib.mkIf config.myNixOS.profiles.workstation.enable {
    home-manager.users.taxborn.imports = [ self.homeModules.profile-workstation ];

    age.identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/home/taxborn/.config/age/yubikey-identity.txt"
    ];

    myNixOS = {
      base.enable = true;
      services = {
        yubikey.enable = true;
      };
    };
  };
}
