{
  config,
  self,
  ...
}:
let
  networkMap = config.homelab.services;
in
{
  age.secrets.ntfy.file = "${self}/secrets/ntfy.age";

  services.ntfy-sh = {
    enable = true;
    environmentFile = config.age.secrets.ntfy.path;

    settings = {
      base-url = "https://${networkMap.ntfy.domain}";
      listen-http = "127.0.0.1:${toString networkMap.ntfy.port}";

      behind-proxy = true;

      # ntfy's default is read-write for everyone.
      auth-default-access = "deny-all";
      enable-login = true;

    };
  };

  homelab.backups.extraExcludes = [
    "/var/lib/private/ntfy-sh"
  ];
}
