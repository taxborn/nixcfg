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
            description = "SSH clone hostname, set with sshPort so clients and the git server agree.";
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
      glance = {
        domain = "www.biscuits.at";
        port = 3000;
      };

      # Paperless-ngx, one of the services on Helium. Its record points at
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

      # Shell history sync.
      atuin = {
        domain = "atuin.biscuits.at";
        port = 3008;
      };

      # The personal website, on Carbon. Not under `biscuits.at`, but it shares
      # the registry so the module and the vhost read one port.
      braxton-is = {
        domain = "braxton.is";
        port = 3006;
      };

      # Push notifications.
      ntfy = {
        domain = "ntfy.biscuits.at";
        port = 3007;
      };

      # Grafana, on Helium next to Paperless. Same trick as `paperless`: a
      # public record holding a tailnet address, so it resolves for anyone and
      # answers only on the tailnet. See hosts/helium/proxy.nix.
      grafana = {
        domain = "grafana.biscuits.at";
        port = 3009;
      };

      piper = {
        domain = "piper.biscuits.at";
        port = 3005;
      };

      # Tangled's knot, on Argon. HTTP is public through Cloudflare. Git over
      # SSH is tailnet-only, so `sshDomain` is Argon's MagicDNS name rather
      # than a public record, and the clients reach it through an ssh_config
      # alias for the public name. Both ends read it from here, the alias and
      # the knot's listener, so they cannot drift apart.
      #
      # 2223 dates from Forgejo holding 2222, the knot's own default. It stays
      # now that Forgejo is gone, because every existing remote and
      # known_hosts entry names this port.
      knot = {
        domain = "knot.biscuits.at";
        sshDomain = "argon.${config.mySnippets.tailnet.name}";
        port = 3011;
        sshPort = 2223;
      };

      # Tangled's spindle (CI), on Carbon.
      spindle = {
        domain = "spindle.biscuits.at";
        port = 3012;
      };

      vaultwarden = {
        domain = "vw.biscuits.at";
        port = 3001;
      };
    };
  };
}
