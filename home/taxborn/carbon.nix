{
  imports = [
    ./default.nix
  ];

  features = {
    cli = {
      fish.enable = true;
      git.enable = true;
      tmux.enable = true;
    };
  };
}
