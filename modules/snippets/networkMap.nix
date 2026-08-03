{
  config,
  lib,
  ...
}:
{
  options.mySnippets.mischief-town.networkMap = lib.mkOption {
    type = lib.types.attrs;
    description = "Hostnames, ports, and vHosts for mischief.town services.";

    default = {
      vaultwarden = {
        domain = "vw.mischief.town";
        port = 3000;
      };

      forgejo = {
        domain = "git.mischief.town";
        port = 3001;
        sshDomain = "carbon.${config.mySnippets.tailnet.name}";
        sshPort = 2222;
      };
    };
  };
}
