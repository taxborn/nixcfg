{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.firefox.enable = lib.mkEnableOption "firefox web browser";

  config = lib.mkIf config.myHome.programs.firefox.enable {
    programs.firefox = {
      enable = true;
      configPath = "${config.xdg.configHome}/mozilla/firefox";
      profiles = {
        default = {
          id = 0;

          settings =
            (import ./betterfox/fastfox.nix)
            // (import ./betterfox/peskyfox.nix)
            // (import ./betterfox/securefox.nix)
            // {
              "browser.tabs.groups.enabled" = true;
              "browser.tabs.groups.smart.enabled" = true;
              "browser.toolbars.bookmarks.visibility" = "newtab";
              "sidebar.revamp" = true;
              "svg.context-properties.content.enabled" = true;
            };
        };
      };
    };
  };
}
