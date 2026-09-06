{
  config,
  lib,
  ...
}:
let
  # Port zero chooses a listener at runtime, which a shared proxy registry cannot use.
  portType = lib.types.ints.between 1 65535;
in
{
  options.mySnippets.biscuits-at.networkMap = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          domain = lib.mkOption {
            type = lib.types.nonEmptyStr;
            description = "Public service name shared by the application and its Caddy vhost.";
          };
          port = lib.mkOption {
            type = portType;
            description = "Loopback HTTP port shared by the application and its Caddy proxy.";
          };
          sshDomain = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            default = null;
            description = "SSH clone hostname, set with sshPort so clients and the forge agree.";
          };
          sshPort = lib.mkOption {
            type = lib.types.nullOr portType;
            default = null;
            description = "SSH clone port, separate from the HTTP listener.";
          };
        };
      }
    );
    apply = lib.mapAttrs (
      name: entry:
      assert lib.assertMsg (
        (entry.sshDomain == null) == (entry.sshPort == null)
      ) "networkMap.${name}: set sshDomain and sshPort together.";
      entry
    );
    description = ''
      Domain, port, and where relevant the SSH details for each biscuits.at
      service.

      There is exactly one of these on purpose. The service module and the
      Caddy vhost read the same entry, so a port cannot be changed in one and
      missed in the other. Never write a port literal into a vhost.
    '';

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

      piper = {
        domain = "piper.biscuits.at";
        port = 3005;
      };

      vaultwarden = {
        domain = "vw.biscuits.at";
        port = 3001;
      };
    };
  };
}
