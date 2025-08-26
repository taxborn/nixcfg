{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Network diagnostic tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils # `dig` + `nslookup`
    ldns # replacement of `dig`, provides the command `drill`
    nmap # A utility for network discovery and security auditing
    ipcalc # calculator for IPv4/v6 addresses

    # Network utilities
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
  ];
}
