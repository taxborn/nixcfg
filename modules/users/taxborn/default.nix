{
  config,
  lib,
  self,
  ...
}:
{
  config = lib.mkIf config.myUsers.taxborn.enable {
    users.users.taxborn = {
      description = "Braxton Fair";
      extraGroups = config.myUsers.defaultGroups;
      hashedPassword = config.myUsers.taxborn.password;
      isNormalUser = true;

      openssh.authorizedKeys.keyFiles = lib.map (file: "${self.inputs.secrets}/publicKeys/${file}") (
        lib.filter (file: lib.hasPrefix "taxborn_" file) (
          builtins.attrNames (builtins.readDir "${self.inputs.secrets}/publicKeys")
        )
      );

      uid = 1000;
    };

  };
}
