{
  imports = [
    ./sites/paperless.nix
  ];

  services.caddy = {
    enable = true;
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
