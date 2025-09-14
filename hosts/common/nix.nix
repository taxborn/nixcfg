{
  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    trusted-users = [
      "root"
      "taxborn"
      "@wheel"
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  programs.nix-ld.enable = true;
}
