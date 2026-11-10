{
  config,
  lib,
  self,
  ...
}:
{
  options.mySnippets.ssh.knownHosts = lib.mkOption {
    type = lib.types.attrs;
    description = ''
      Host key pins, one entry per host, listed under every name that host is
      reached by: bare, MagicDNS, and tailnet IP. known_hosts matches per name,
      so a name left off this list is one that still falls back to
      trust-on-first-use.

      No `.local` names. No host runs avahi, so nothing resolves them, and a
      pin for a name that cannot be reached only reads as if mDNS were in use.

      The key files are the same `keys/root_<host>.pub` that secrets/secrets.nix
      encrypts to, so a host has one identity across ssh and agenix rather than
      two that can drift.
    '';

    default = {
      argon = {
        hostNames = [
          "argon"
          "argon.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.argon
        ];
        publicKeyFile = "${self}/keys/root_argon.pub";
      };

      carbon = {
        hostNames = [
          "carbon"
          "carbon.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.carbon
        ];
        publicKeyFile = "${self}/keys/root_carbon.pub";
      };

      helium = {
        hostNames = [
          "helium"
          "helium.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.helium
        ];
        publicKeyFile = "${self}/keys/root_helium.pub";
      };

      uranium = {
        hostNames = [
          "uranium"
          "uranium.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.uranium
        ];
        publicKeyFile = "${self}/keys/root_uranium.pub";
      };

      tungsten = {
        hostNames = [
          "tungsten"
          "tungsten.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.tungsten
        ];
        publicKeyFile = "${self}/keys/root_tungsten.pub";
      };
    };
  };
}
