{
  config,
  lib,
  pkgs,
  ...
}:
let
  engines = import ../firefox/engines.nix;
in
{
  options.myHome.taxborn.programs.zen.enable = lib.mkEnableOption "zen web browser";

  config = lib.mkIf config.myHome.taxborn.programs.zen.enable {
    programs.zen-browser = {
      enable = true;
      nativeMessagingHosts = [ pkgs.bitwarden-desktop ];

      profiles = {
        default = {
          id = 0;

          search = {
            inherit engines;
            default = "Kagi";
            force = true;

            order = [
              "bing"
              "Brave"
              "ddg"
              "google"
              "Home Manager Options"
              "Kagi"
              "NixOS Wiki"
              "nixpkgs"
              "Noogle"
              "Wikipedia"
              "Wiktionary"
            ];
          };

          settings = {
            "zen.tabs.vertical.right-side" = false;
            "zen.welcome-screen.seen" = true;
            "zen.workspaces.continue-where-left-off" = true;
          };
        };
      };
    };
  };
}
