{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  programs.nix-ld.enable = true;
}
