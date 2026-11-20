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

    owner = {
      name = mkOption { type = types.str; };
      email = mkOption { type = types.str; };
      username = mkOption { type = types.str; };
      gpgKey = mkOption { type = types.str; };
      did = mkOption { type = types.strMatching "^did:[a-z]+:.+"; };
    };

    mail = {
      host = mkOption { type = types.str; };
      port = mkOption { type = port; };
      from = mkOption { type = types.str; };
      atproto = mkOption { type = types.str; };
    };

    ntfy.topics = mkOption { type = types.attrsOf types.str; };

    rsyncNet = {
      user = mkOption { type = types.str; };
      host = mkOption { type = types.str; };
    };

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

  config.homelab = lib.mapAttrsRecursive (_: lib.mkDefault) data;
}
