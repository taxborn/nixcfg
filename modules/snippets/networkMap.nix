{
  lib,
  ...
}:
{
  options.mySnippets.biscuits-at.networkMap = lib.mkOption {
    type = lib.types.attrs;
    description = "Hostnames, ports, and vHosts for biscuits.at services.";

    default = {
      glance = {
        domain = "www.biscuits.at";
        port = 3000;
      };
    };
  };
}
