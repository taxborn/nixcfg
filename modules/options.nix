{ lib, self, ... }:
let
  inherit (lib) mkOption types;
  data = import "${self}/homelab.nix";

  port = types.ints.between 1 65535;
  hostList = mkOption { type = types.listOf types.str; };
  service = types.submodule {
    options = {
      domain = mkOption { type = types.nonEmptyStr; };
      port = mkOption { type = port; };
      sshDomain = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
      };
      sshPort = mkOption {
        type = types.nullOr port;
        default = null;
      };
    };
  };
in
{
  options.homelab = {
    domain = mkOption { type = types.nonEmptyStr; };

    hosts = mkOption {
      type = types.attrsOf types.str;
      description = "Every host in the fleet, mapped to its tailnet address.";
    };

    tailnet = {
      name = mkOption { type = types.str; };
      ranges = mkOption { type = types.listOf types.str; };
    };

    services = mkOption {
      type = types.attrsOf service;
      apply = lib.mapAttrs (
        name: entry:
        assert lib.assertMsg (
          (entry.sshDomain == null) == (entry.sshPort == null)
        ) "homelab.services.${name}: set sshDomain and sshPort together.";
        entry
      );
    };

    backupServer = {
      host = mkOption { type = types.str; };
      user = mkOption { type = types.str; };
      basePath = mkOption { type = types.str; };
      port = mkOption { type = port; };
    };

    monitoring = {
      server = mkOption { type = types.str; };
      alwaysOn = hostList;
      physicalDisks = hostList;
      minecraftHosts = hostList;
      ports = mkOption { type = types.attrsOf port; };
    };
  };

  config.homelab = lib.mkDefault data;
}
