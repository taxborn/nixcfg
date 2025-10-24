{
  pkgs,
  config,
  inputs,
  ...
}:

{
  imports = [
    ../common
    ./caddy.nix

    ./hardware-configuration.nix
    ./disks.nix
    ./backup.nix
  ];

  networking.hostName = "carbon";
  time.timeZone = "America/Chicago";

  environment.systemPackages = with pkgs; [
    jdk21_headless

    inputs.agenix.packages."${system}".default
  ];
  networking.firewall.allowedTCPPorts = [
    25565
    25566
  ];

  services.openssh.extraConfig = "StreamLocalBindUnlink yes";

  age.secrets.forgejo-key = {
    file = ../../secrets/forgejo-token.age;
  };

  services.gitea-actions-runner = {
    package = pkgs.forgejo-actions-runner;
    instances.mischief-town = {
      enable = true;
      name = "carbon";
      tokenFile = config.age.secrets.forgejo-key.path;
      url = "https://git.mischief.town/";
      labels = [
        "node-22:docker://node:22-bookworm"
        "nixos-latest:docker://nixos/nix"
      ];
    };
  };

  system.stateVersion = "25.05";
}
