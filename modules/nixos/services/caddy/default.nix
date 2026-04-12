{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
  options.myNixOS.services.caddy.enable = lib.mkEnableOption "Caddy web server.";

  config = lib.mkIf config.myNixOS.services.caddy.enable {
    age.secrets.tailscaleCaddyAuth.file = "${self.inputs.secrets}/tailscale/caddyAuth.age";
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services = {
      caddy = {
        enable = true;
        # Graceful reload is disabled because the tailscale caddy plugin does not
        # survive a config reload - it must do a full restart to re-register the
        # Tailscale node. Do not re-enable this without testing the plugin first.
        enableReload = false;
        environmentFile = config.age.secrets.tailscaleCaddyAuth.path;

        globalConfig = ''
          tailscale {
            ephemeral true
          }
        '';

        package = pkgs.caddy.withPlugins {
          plugins = [ "github.com/tailscale/caddy-tailscale@v0.0.0-20250508175905-642f61fea3cc" ];
          hash = "sha256-S6vXxRMJMynh7bmHy2mNl+kyJ5csjUqunu9aaFTwb2M=";
        };
      };

      tailscale.permitCertUid = "caddy";
    };
  };
}
