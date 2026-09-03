{
  config,
  lib,
  self,
  ...
}:
{
  options.mySnippets.ssh.knownHosts = lib.mkOption {
    type = lib.types.attrs;
    description = "Default ssh known hosts.";

    default = {
      argon = {
        hostNames = [
          "argon"
          "argon.local"
          "argon.${config.mySnippets.tailnet.name}"
          "135.148.121.190"
          config.mySnippets.tailnet.tailscaleIPs.argon
        ];
        publicKeyFile = "${self}/keys/root_argon.pub";
      };

      carbon = {
        hostNames = [
          "carbon"
          "carbon.local"
          "carbon.${config.mySnippets.tailnet.name}"
          "15.204.91.84"
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
