{ config, lib, ... }:
{
  options.mySnippets.mischief-town.networkMap = lib.mkOption {
    type = lib.types.attrs;
    description = "Hostnames, ports, and vHosts for mischief.town services.";

    default = {
      tailscaleIPs = {
        uranium = "100.64.0.0";
        tungsten = "100.64.0.1";
        helium = "100.64.1.0";
        carbon = "100.64.2.0";
        argon = "100.64.2.1";
      };

      vaultwarden = {
        domain = "vw.mischief.town";
        port = 3001;
      };

      pds = {
        domain = "pds.mischief.town";
        port = 3002;
      };

      grafana = {
        domain = "grafana.${config.mySnippets.tailnet.name}";
        port = 3000;
      };

      prometheus = {
        port = 9090;
      };

      loki = {
        port = 3100;
      };

      nodeExporter = {
        port = 9100;
      };

      glance = {
        domain = "www.mischief.town";
        port = 3003;
      };

      forgejo = {
        domain = "git.mischief.town";
        internalHost = "carbon.${config.mySnippets.tailnet.name}";
        port = 3004;
      };
    };
  };
}
