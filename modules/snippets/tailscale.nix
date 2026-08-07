{
  lib,
  ...
}:
{
  options.mySnippets.tailnet = {
    name = lib.mkOption {
      default = "tucuxi-hexatonic.ts.net";
      description = "Tailnet name.";
      type = lib.types.str;
    };

    tailscaleIPs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = ''
        Hostname to Tailscale IP mapping for hosts on the tailnet.

        This doubles as the fleet roster. `services.backups` addresses the
        backup server through it, and the monitoring server derives its scrape
        targets from it — which is why the two options below are lists of names
        drawn from here rather than a second registry of their own. A host that
        is not in here is not backed up and not monitored, and that is the only
        place to fix either.
      '';
      default = {
        argon = "100.64.2.1";
        carbon = "100.64.2.0";
        helium = "100.64.1.0";
        uranium = "100.64.0.0";
        tungsten = "100.64.0.1";
      };
    };

    alwaysOn = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "argon"
        "carbon"
        "helium"
      ];
      example = lib.literalExpression ''[ "argon" ]'';
      description = ''
        Hosts whose absence is a fault rather than a Tuesday.

        Prometheus scrapes every host in `tailscaleIPs`, but only these land in
        the `node` job; the rest go to `node-intermittent`, and the down alert
        covers `node` alone. Tungsten is a laptop and Uranium is a desktop, so
        `up == 0` is their ordinary state — a rule that fires every time a lid
        closes is a rule that gets muted, and muting it costs the one that
        mattered.

        This only decides alerting. Metrics are collected from an intermittent
        host exactly the same way whenever it is awake, and its dashboards work.
      '';
    };

    physicalDisks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "helium"
        "tungsten"
        "uranium"
      ];
      example = lib.literalExpression ''[ "helium" ]'';
      description = ''
        Hosts with real disks to ask about SMART, as opposed to a VPS's virtio
        devices, which answer nothing.

        Both halves of the SMART pipeline read this, so they cannot drift: the
        client decides whether to run `smartctl_exporter` at all, and the server
        decides whether to scrape it. Getting that wrong in either direction is
        silent — an unscraped exporter, or a target that is permanently down and
        teaches you to ignore down targets.

        Argon and Carbon are OVH instances, and
        `modules/hardware/profiles/ovh.nix` already turns `services.smartd` off
        there for the same reason. The client module asserts the two agree.
      '';
    };
  };
}
