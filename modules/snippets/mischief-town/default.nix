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
    };
  };
}
