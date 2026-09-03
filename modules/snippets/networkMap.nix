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
        # DNS-only record straight to argon. Cloudflare's proxy in front of
        # `domain` carries HTTP only, so SSH needs a name that bypasses it.
        sshDomain = "git.biscuits.at";
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
