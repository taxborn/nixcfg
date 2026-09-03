{
  config,
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
        # Git over SSH is tailnet-only, so this is argon's MagicDNS name and
        # not a public record. Both ends read it from here — the ssh_config
        # alias on the clients and the clone URL Forgejo prints — so they
        # cannot drift apart.
        sshDomain = "argon.${config.mySnippets.tailnet.name}";
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
