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
}
