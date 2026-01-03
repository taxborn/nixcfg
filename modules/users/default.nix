{
  config,
  lib,
  self,
  pkgs,
  ...
}:
{
  imports = [
    ./taxborn
    ./options.nix
  ];

  config = lib.mkIf (config.myUsers.root.enable or config.myUsers.taxborn.enable) {
    programs.fish.enable = true;
    # as of 2026-01-02 this takes a whileeee and haven't needed it yet.
    documentation.man.generateCaches = false;

    users = {
      defaultUserShell = pkgs.fish;
      mutableUsers = false;

      users.root.openssh.authorizedKeys.keyFiles =
        lib.map (file: "${self.inputs.secrets}/publicKeys/${file}")
          (
            lib.filter (file: lib.hasPrefix "taxborn_" file) (
              builtins.attrNames (builtins.readDir "${self.inputs.secrets}/publicKeys")
            )
          );
    };
  };

}
