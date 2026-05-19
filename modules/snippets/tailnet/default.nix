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
      description = "Hostname to Tailscale IP mapping for hosts on the tailnet.";
      default = {
        uranium = "100.64.0.0";
        tungsten = "100.64.0.1";
        # FIXME: re-enable once server configs are in-tree
        # helium = "100.64.1.0";
        # carbon = "100.64.2.0";
        # argon = "100.64.2.1";
      };
    };
  };
}
