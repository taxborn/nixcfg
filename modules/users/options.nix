{ lib, ... }:
{
  options.myUsers =
    let
      mkUser = user: {
        enable = lib.mkEnableOption "${user}.";

        password = lib.mkOption {
          default = null;
          description = "Hashed password for ${user}.";
          type = lib.types.nullOr lib.types.str;
        };
      };
    in
    {
      defaultGroups = lib.mkOption {
        description = "Default groups for desktop users.";
        default = [
          "docker"
          "libvirtd"
          "networkmanager"
          "video"
          "wheel"
        ];
      };

      root.enable = lib.mkEnableOption "root user configuration." // {
        default = true;
      };
      taxborn = mkUser "taxborn";
    };
}
