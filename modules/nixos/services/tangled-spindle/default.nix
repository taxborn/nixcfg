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

  options.myNixOS.services.tangled-spindle.enable = lib.mkEnableOption "spindle ci for tangled.org";

  config = lib.mkIf config.myNixOS.services.tangled-spindle.enable {
    services.tangled = {
      spindle = {
        enable = true;
        server = {
          listenAddr = "0.0.0.0:${toString config.mySnippets.mischief-town.networkMap.tangled-spindle.port}";
          hostname = config.mySnippets.mischief-town.networkMap.tangled-spindle.vHost;
          owner = "did:plc:2grdruc2p6fjhksrfpt366yl";
        };
        pipelines.workflowTimeout = "10m";
      };
    };

    networking.firewall.allowedTCPPorts = [ 22 ];
  };
}
