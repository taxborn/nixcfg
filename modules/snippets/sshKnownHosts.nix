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
          "15.204.91.84"
        ];
        publicKeyFile = "${self}/keys/root_argon.pub";
      };

      carbon = {
        hostNames = [
          "carbon"
          "carbon.local"
          "carbon.${config.mySnippets.tailnet.name}"
          "135.148.121.190"
        ];
        publicKeyFile = "${self}/keys/root_carbon.pub";
      };

      # The tailnet IP is load-bearing: borg clients address Helium's repository
      # by IP, and ssh matches known_hosts against the literal host it was given.
      helium = {
        hostNames = [
          "helium"
          "helium.local"
          "helium.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.helium
        ];
        publicKeyFile = "${self}/keys/root_helium.pub";
      };
    };
  };
}
