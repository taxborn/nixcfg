{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.adguardhome;
  networkMap = config.mySnippets.biscuits-at.networkMap;
  tailscale = config.myNixOS.services.tailscale;
  tailnetIP = tailscale.address;
in
{
  options.myNixOS.services.adguardhome.enable = lib.mkEnableOption "AdGuard Home DNS ad blocker";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable && tailnetIP != null;
        message = ''
          myNixOS.services.adguardhome listens on this host's tailnet address
          and nowhere else, so the host has to run Tailscale and appear in
          mySnippets.tailnet.tailscaleIPs.
        '';
      }
    ];

    services.adguardhome = {
      enable = true;

      # The web UI stays off the firewall and behind Caddy, like every other
      # service here. Only DNS gets a listener of its own.
      openFirewall = false;

      # Settings are rendered from this file on every start and edits made in
      # the UI are thrown away. Anything worth keeping has to be written here,
      # which is also why the state directory is not backed up below.
      mutableSettings = false;

      settings = {
        http.address = "127.0.0.1:${toString networkMap.adguard.port}";

        dns = {
          # The tailnet address, not 0.0.0.0. The wildcard would also answer on
          # the LAN interface, and while the firewall drops that today, an open
          # resolver is one stray `allowedUDPPorts` away from being reachable
          # by anything that can route to the home network. Bound to this
          # address it can only be asked over the tailnet.
          bind_hosts = [ tailnetIP ];
          port = 53;

          # Plain DNS is needed once, to resolve the DoH hostnames below.
          bootstrap_dns = [
            "9.9.9.9"
            "1.1.1.1"
          ];
          upstream_dns = [
            "https://dns.quad9.net/dns-query"
            "https://cloudflare-dns.com/dns-query"
          ];
        };

        filters = [
          {
            enabled = true;
            id = 1;
            name = "AdGuard DNS filter";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          }
        ];
      };
    };

    # The tailnet address only exists once tailscaled is Running. Without this
    # ordering AdGuard races it at boot, fails to bind and exhausts its start
    # limit, leaving every tailnet device with no DNS until someone notices.
    #
    # The nixpkgs unit sets its own StartLimitIntervalSec and RestartSec, so
    # the shared values have to be forced.
    systemd.services.adguardhome = lib.recursiveUpdate tailscale.bindOrdering {
      unitConfig.StartLimitIntervalSec = lib.mkForce 0;
      serviceConfig.RestartSec = lib.mkForce 5;
    };

    # Declared above, so the state directory holds only the query log and
    # statistics, in bbolt files that are live while the service runs and
    # come out of an archive torn. DynamicUser puts the real directory under
    # /var/lib/private, as it does for ntfy.
    myNixOS.services.backups.client.extraExcludes =
      lib.mkIf config.myNixOS.services.backups.client.enable
        [
          "/var/lib/private/AdGuardHome"
        ];
  };
}
