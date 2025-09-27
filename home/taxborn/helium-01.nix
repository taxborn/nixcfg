{
  imports = [
    ./default.nix
  ];

  features = {
    cli = {
      fish.enable = true;
      tmux.enable = true;
      git.enable = true;
    };
  };

  services.minecraft-server = {
    enable = true;
    eula = true;
    openFirewall = true;
  };
}
