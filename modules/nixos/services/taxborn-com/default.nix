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
          ports = [ "${toString config.mySnippets.mischief-town.networkMap.taxborn-com.port}:8080" ];
        };
      };
    };

    myNixOS.programs.podman.enable = true;
  };
}
