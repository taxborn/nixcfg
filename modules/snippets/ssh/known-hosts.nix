{
  lib,
  ...
}:
{
  # TODO: Incorporate this into my SSH config????
  options.mySnippets.ssh.knownHosts = lib.mkOption {
    type = lib.types.attrs;
    description = "Default ssh known hosts.";

    default = {
      # tungsten = {
      #   hostNames = [
      #     "tungsten"
      #     "tungsten.local"
      #     "tungsten.${config.mySnippets.tailnet.name}"
      #   ];
      #   publicKeyFile = "${self}/secrets/publicKeys/root_tungsten.pub";
      # };
    };
  };
}
