{ pkgs, ... }:

{
  home.packages = with pkgs; [
    dnsutils # `dig` + `nslookup`
    nmap
  ];
}
