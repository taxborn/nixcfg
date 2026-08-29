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
      forgejo = {
        domain = "git.mischief.town";
        port = 3001;

        # The same forge on the tailnet, served by a Caddy vhost bound to a
        # userspace Tailscale node rather than to any of Carbon's interfaces.
        # Actions runners talk to this and never to the public name — see
        # hosts/carbon/proxy.nix for the listener and
        # modules/nixos/services/forgejo/runner.nix for why it matters that
        # every workflow URL is derived from whatever the runner connects to.
        tailnetDomain = "git.${config.mySnippets.tailnet.name}";

        sshDomain = "carbon.${config.mySnippets.tailnet.name}";
        sshPort = 2222;
      };

      glance = {
        domain = "www.mischief.town";
        port = 3002;
      };

      vaultwarden = {
        domain = "vw.mischief.town";
        port = 3000;
      };

      # The atproto PDS. `domain` names the server itself; every account handle
      # is a further label under it (`alice.pds.mischief.town`), which is why
      # this is the one entry here whose Caddy vhost comes as a pair. See
      # hosts/carbon/proxy.nix for why those records are not proxied.
      pds = {
        domain = "pds.mischief.town";
        port = 3009;
      };

      # The monitoring stack, all of it on Argon. Only Grafana has a domain:
      # everything else here is reached by a peer that already knows the port,
      # and none of it is proxied — see modules/nixos/services/monitoring.
      #
      # The 300x numbers continue the sequence above, but the two exporters use
      # their registered upstream defaults instead. Every off-the-shelf
      # dashboard, alert rule and troubleshooting page assumes 9100 for
      # node_exporter, and a local renumbering buys nothing to pay for that.
      monitoring = {
        grafana = {
          domain = "grafana.${config.mySnippets.tailnet.name}";
          port = 3003;
        };

        prometheus.port = 3004;
        alertmanager.port = 3005;
        alertmanagerNtfy.port = 3006;
        loki = {
          port = 3007;

          # Loki's ring advertises whatever port is *configured*, not the one
          # the listener ended up on, so the single-binary gRPC socket cannot
          # be left at 0 for the kernel to choose — the compactor then dials
          # 127.0.0.1:0 to reach itself and fails once a minute forever.
          grpcPort = 3008;
        };

        nodeExporter.port = 9100;
        smartctlExporter.port = 9633;
      };
    };
  };
}
