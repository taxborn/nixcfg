{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.programs.bitwarden = {
    enable = lib.mkEnableOption "Bitwarden password manager with rofi integration";

    email = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Bitwarden account email for rbw CLI/rofi-rbw integration. See secrets/bitwarden.md.";
      example = "user@example.com";
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Base URL for a self-hosted Vaultwarden/Bitwarden server. Defaults to the official Bitwarden servers if null.";
      example = "https://vw.example.com";
    };
  };

  config = lib.mkIf config.myHome.programs.bitwarden.enable {
    home.packages = with pkgs; [
      bitwarden-desktop
      rofi-rbw
      wtype # Wayland typing tool for rofi-rbw
    ];

    programs.rbw = lib.mkIf (config.myHome.programs.bitwarden.email != null) {
      enable = true;
      settings = {
        email = config.myHome.programs.bitwarden.email;
        lock_timeout = 300;
        pinentry = pkgs.pinentry-gnome3;
      }
      // lib.optionalAttrs (config.myHome.programs.bitwarden.baseUrl != null) {
        base_url = config.myHome.programs.bitwarden.baseUrl;
      };
    };
  };
}
