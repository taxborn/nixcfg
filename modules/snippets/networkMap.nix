{
  lib,
  ...
}:
{
  options.mySnippets.biscuits-at.networkMap = lib.mkOption {
    type = lib.types.attrs;
    description = "Hostnames, ports, and vHosts for biscuits.at services.";

    default = {
      forgejo = {
        domain = "code.biscuits.at";
        port = 3002;
        sshPort = 2222;
      };

      glance = {
        domain = "www.biscuits.at";
        port = 3000;
      };

      vaultwarden = {
        domain = "vw.biscuits.at";
        port = 3001;
      };
    };
  };
}
