{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.taxborn-com.enable = lib.mkEnableOption "taxborn.com personal website";

  config = lib.mkIf config.myNixOS.services.taxborn-com.enable {
    virtualisation.oci-containers = {
      backend = "podman";

      containers = {
        taxborn-com = {
          extraOptions = [ "--pull=always" ];
          image = "git.mischief.town/taxborn/taxborn.com";
          ports = [ "0.0.0.0:${toString config.mySnippets.mischief-town.networkMap.taxborn-com.port}:80" ];
        };
      };
    };

    myNixOS.programs.podman.enable = true;
  };
}
