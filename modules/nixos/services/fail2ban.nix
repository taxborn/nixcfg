{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.fail2ban;
in
{
  options.myNixOS.services.fail2ban.enable = lib.mkEnableOption "fail2ban intrusion prevention";

  config = lib.mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";

      bantime-increment = {
        enable = true;
        multipliers = "2 4 8 16 32 64";
        maxtime = "168h";
        overalljails = true;
      };

      ignoreIP = [
        # Ignore Tailscale range
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];

      jails.sshd.settings.maxretry = 3;
    };
  };
}
