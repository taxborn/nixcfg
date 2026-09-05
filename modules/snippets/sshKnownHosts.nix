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
      reached by: bare, `.local`, MagicDNS, and tailnet IP. known_hosts matches
      per name, so a name left off this list is one that still falls back to
      trust-on-first-use.

      The key files are the same `keys/root_<host>.pub` that secrets/secrets.nix
      encrypts to, so a host has one identity across ssh and agenix rather than
      two that can drift.
    '';

    default = {
      argon = {
        hostNames = [
          "argon"
          "argon.local"
          "argon.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.argon
        ];
        publicKeyFile = "${self}/keys/root_argon.pub";
      };

      carbon = {
        hostNames = [
          "carbon"
          "carbon.local"
          "carbon.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.carbon
        ];
        publicKeyFile = "${self}/keys/root_carbon.pub";
      };

      helium = {
        hostNames = [
          "helium"
          "helium.local"
          "helium.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.helium
        ];
        publicKeyFile = "${self}/keys/root_helium.pub";
      };

      uranium = {
        hostNames = [
          "uranium"
          "uranium.local"
          "uranium.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.uranium
        ];
        publicKeyFile = "${self}/keys/root_uranium.pub";
      };

      tungsten = {
        hostNames = [
          "tungsten"
          "tungsten.local"
          "tungsten.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.tungsten
        ];
        publicKeyFile = "${self}/keys/root_tungsten.pub";
      };
    };
  };
}
