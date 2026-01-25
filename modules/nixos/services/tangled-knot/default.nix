{
  config,
  lib,
  self,
  ...
}:
{
  imports = [
    self.inputs.tangled.nixosModules.knot
  ];

  options.myNixOS.services.tangled-knot.enable = lib.mkEnableOption "knotserver for tangled.org";

  config = lib.mkIf config.myNixOS.services.tangled-knot.enable {
    services.tangled = {
      knot = {
        enable = true;
        gitUser = "git";
        stateDir = "/var/lib/tangled-knot";
        repo.scanPath = "/var/lib/tangled-knot/repos";
        server = {
          listenAddr = "0.0.0.0:${toString config.mySnippets.mischief-town.networkMap.tangled-knot.port}";
          hostname = config.mySnippets.mischief-town.networkMap.tangled-knot.vHost;
          internalListenAddr = "127.0.0.1:${toString config.mySnippets.mischief-town.networkMap.tangled-knot.internalPort}";
          owner = "did:plc:2grdruc2p6fjhksrfpt366yl";
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 22 ];
  };
}
