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
        ];
        publicKeyFile = "${self}/keys/root_argon.pub";
      };

      carbon = {
        hostNames = [
          "carbon"
          "carbon.local"
          "carbon.${config.mySnippets.tailnet.name}"
          "15.204.91.84"
        ];
        publicKeyFile = "${self}/keys/root_carbon.pub";
      };

      # The tailnet IP is load-bearing: borg clients address Helium's repository
      # by IP, and ssh matches known_hosts against the literal host it was given.
      #
      # The bracketed entry is the same host on the borg port. ssh keys
      # known_hosts by `[host]:port` for any port other than 22, so without it
      # every backup run fails host key verification even though the plain IP
      # is right there on the line above.
      helium = {
        hostNames = [
          "helium"
          "helium.local"
          "helium.${config.mySnippets.tailnet.name}"
          config.mySnippets.tailnet.tailscaleIPs.helium
          "[${config.mySnippets.tailnet.tailscaleIPs.helium}]:${toString config.myNixOS.services.backups.server.sshPort}"
        ];
        publicKeyFile = "${self}/keys/root_helium.pub";
      };

      uranium = {
        hostNames = [
          "uranium"
          "uranium.local"
          "uranium.${config.mySnippets.tailnet.name}"
        ];
        publicKeyFile = "${self}/keys/root_uranium.pub";
      };

      tungsten = {
        hostNames = [
          "tungsten"
          "tungsten.local"
          "tungsten.${config.mySnippets.tailnet.name}"
        ];
        publicKeyFile = "${self}/keys/root_tungsten.pub";
      };
    };
  };
}
