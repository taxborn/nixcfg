{
  lib,
  ...
}:
{
  options.mySnippets.tailnet = {
    name = lib.mkOption {
      default = "tucuxi-hexatonic.ts.net";
      description = ''
        MagicDNS suffix for the tailnet. Everything that builds a
        `<host>.<tailnet>` name reads it from here: the known-hosts pins and
        Forgejo's SSH domain, which is a MagicDNS name because git over SSH is
        tailnet-only.
      '';
      type = lib.types.str;
    };

    ranges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];
      description = ''
        Tailscale's CGNAT block and its ULA prefix. A remote address inside
        either is a tailnet peer. `services.fail2ban` exempts them from bans
        and asserts they cover `tailscaleIPs`, and Argon's tailnet-only Forgejo
        vhost aborts any peer outside them, so the two cannot drift apart.
      '';
    };

    tailscaleIPs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = ''
        Hostname to Tailscale IP mapping, and the fleet roster.

        `services.backups` addresses the backup server through it, so a host
        missing from here is a host that is not backed up, and this is the only
        place to fix that. `services.fail2ban` asserts its `ignoreIP` covers
        every address in here, because fail2ban hooks its chains ahead of the
        firewall's accept for trusted interfaces and a ban landing on a tailnet
        address takes out the path used to lift it.
      '';
      default = {
        argon = "100.64.2.1";
        carbon = "100.64.2.0";
        helium = "100.64.1.0";
        uranium = "100.64.0.0";
        tungsten = "100.64.0.1";
      };
    };

  };
}
