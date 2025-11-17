{
  imports = [
    ./sites/mischief.nix
    ./sites/taxborn.nix
    ./sites/vaultwarden.nix
    ./sites/forgejo.nix
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
