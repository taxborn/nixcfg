{
  config,
  lib,
  ...
}:
let

  tailnetRanges = config.homelab.tailnet.ranges;

  isIPv4 = addr: !(lib.hasInfix ":" addr);

  ipv4ToInt = addr: lib.foldl' (acc: octet: acc * 256 + lib.toInt octet) 0 (lib.splitString "." addr);

  containsIPv4 =
    cidr: addr:
    let
      parts = lib.splitString "/" cidr;
      network = ipv4ToInt (lib.head parts);
      # No shift operator in Nix.
      size = lib.foldl' (acc: _: acc * 2) 1 (lib.range 1 (32 - lib.toInt (lib.elemAt parts 1)));
      address = ipv4ToInt addr;
    in
    address >= network && address < network + size;

  # IPv6 addresses count as uncovered, so a new one trips the assertion instead of a ban.
  covered =
    addr: isIPv4 addr && lib.any (cidr: containsIPv4 cidr addr) (lib.filter isIPv4 tailnetRanges);

  uncovered = lib.filter (addr: !covered addr) (lib.attrValues config.homelab.hosts);
in
{
  # fail2ban runs ahead of trustedInterfaces, so ignoreIP alone keeps a ban off the tailnet.
  assertions = [
    {
      assertion = uncovered == [ ];
      message = ''
        fail2ban ignores ${lib.concatStringsSep " " tailnetRanges}, which does
        not cover ${lib.concatStringsSep " " uncovered} from
        homelab.hosts. A ban on that address would take the
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
    };

    ignoreIP = tailnetRanges;

    jails.sshd.settings.maxretry = 3;
  };
}
