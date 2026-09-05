{
  lib,
  ...
}:
{
  options.mySnippets.tailnet = {
    name = lib.mkOption {
      default = "tucuxi-hexatonic.ts.net";
      description = ''
        MagicDNS suffix for the tailnet. Everything that builds a
        `<host>.<tailnet>` name reads it from here: the known-hosts pins and
        Forgejo's SSH domain, which is a MagicDNS name because git over SSH is
        tailnet-only.
      '';
      type = lib.types.str;
    };

    tailscaleIPs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = ''
        Hostname to Tailscale IP mapping, and the fleet roster.

        `services.backups` addresses the backup server through it, so a host
        missing from here is a host that is not backed up, and this is the only
        place to fix that. `services.fail2ban` asserts its `ignoreIP` covers
        every address in here, because fail2ban hooks its chains ahead of the
        firewall's accept for trusted interfaces and a ban landing on a tailnet
        address takes out the path used to lift it.

        The two options below are lists of names drawn from here rather than
        registries of their own, though nothing currently reads either.
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
        Hosts whose absence is a fault rather than a Tuesday. Tungsten is a
        laptop and Uranium is a desktop, so `up == 0` is their ordinary state.

        Nothing reads this. It split Prometheus' `node` scrape job from
        `node-intermittent` so the down alert covered only the hosts where down
        meant something: a rule that fires every time a lid closes is a rule
        that gets muted, and muting it costs the one that mattered. The
        monitoring module was deleted in f4012fc and this outlived it.

        Kept because the list is still right and the judgement behind it is the
        expensive part to redo. Anything that grows a liveness alert should read
        it rather than start a second list.
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
        devices, which answer nothing. Argon and Carbon are the OVH instances
        left out, and `modules/hardware/profiles/ovh.nix` turns `smartd` off on
        them for the same reason, against the `mkDefault true` in
        modules/nixos/base.nix.

        Nothing reads this. Both halves of the SMART pipeline did, the client
        deciding whether to run `smartctl_exporter` and the server deciding
        whether to scrape it, which is what kept them from drifting into an
        unscraped exporter or a permanently down target that teaches you to
        ignore down targets. The monitoring module was deleted in f4012fc and
        this outlived it.

        Nothing asserts that this list and the `ovh` hardware profile agree.
        They do today, by hand.
      '';
    };
  };
}
