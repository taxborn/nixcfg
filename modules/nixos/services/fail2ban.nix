{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.fail2ban;

  # Tailscale's CGNAT block and its ULA prefix. A ban that lands on either is
  # a ban on the path used to lift the ban.
  tailnetRanges = [
    "100.64.0.0/10"
    "fd7a:115c:a1e0::/48"
  ];

  isIPv4 = addr: !(lib.hasInfix ":" addr);

  ipv4ToInt = addr: lib.foldl' (acc: octet: acc * 256 + lib.toInt octet) 0 (lib.splitString "." addr);

  containsIPv4 =
    cidr: addr:
    let
      parts = lib.splitString "/" cidr;
      network = ipv4ToInt (lib.head parts);
      # No shift operator in Nix, so double a prefix's worth of times.
      size = lib.foldl' (acc: _: acc * 2) 1 (lib.range 1 (32 - lib.toInt (lib.elemAt parts 1)));
      address = ipv4ToInt addr;
    in
    address >= network && address < network + size;

  # v6 addresses fall through as uncovered rather than being waved past, so a
  # roster that grows one trips the assertion instead of the ban.
  covered =
    addr: isIPv4 addr && lib.any (cidr: containsIPv4 cidr addr) (lib.filter isIPv4 tailnetRanges);

  uncovered = lib.filter (addr: !covered addr) (
    lib.attrValues config.mySnippets.tailnet.tailscaleIPs
  );
in
{
  options.myNixOS.services.fail2ban.enable = lib.mkEnableOption "fail2ban intrusion prevention";

  config = lib.mkIf cfg.enable {
    # fail2ban hooks its ban chains onto the head of INPUT, ahead of the
    # firewall's accept for trustedInterfaces, so ignoreip is the only thing
    # holding the tailnet open. That makes the roster and the ranges below a
    # pair that has to agree, and nothing else checks that they do.
    assertions = [
      {
        assertion = uncovered == [ ];
        message = ''
          fail2ban ignores ${lib.concatStringsSep " " tailnetRanges}, which does
          not cover ${lib.concatStringsSep " " uncovered} from
          mySnippets.tailnet.tailscaleIPs. A ban on that address would take the
          tailnet with it.
        '';
      }
    ];

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

      # The tailnet is the whole exemption. A public address stays bannable,
      # including my own, which is the point of the jail. It costs no access,
      # because tailnet SSH answers on a different address and that one is
      # covered here.
      ignoreIP = tailnetRanges;

      # The module declares the sshd jail itself, enabled and already pointed
      # at the right port and filter, so all this does is tighten its retry
      # budget below the global maxretry.
      jails.sshd.settings.maxretry = 3;
    };
  };
}
