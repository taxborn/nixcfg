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

      # Paperless-ngx, the one service not on Argon. Its record points at
      # Helium's tailnet address rather than a routable one, so the name
      # resolves for anyone and answers only on the tailnet — see
      # hosts/helium/proxy.nix.
      paperless = {
        domain = "docs.biscuits.at";
        port = 3004;
      };

      # The atproto PDS. `domain` names the server itself; every account handle
      # is a further label under it (`alice.pds.biscuits.at`), which is why this
      # is the one entry here whose Caddy vhost comes as a pair. See
      # hosts/argon/proxy.nix for why those two records are the only ones in
      # the zone that Cloudflare does not proxy.
      pds = {
        domain = "pds.biscuits.at";
        port = 3003;
      };

      vaultwarden = {
        domain = "vw.biscuits.at";
        port = 3001;
      };
    };
  };
}
