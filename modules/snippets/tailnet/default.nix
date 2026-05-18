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
  };
}
