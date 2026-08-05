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
    };
  };
}
