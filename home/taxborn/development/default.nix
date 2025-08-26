{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Braxton Fair";
    userEmail = "hello@taxborn.com";

    lfs.enable = true;

    signing.key = "F22AFD6CFD66B874";
    signing.signByDefault = true;
  };

  home.packages = with pkgs; [
    # Static site generator
    hugo

    # Markdown previewer
    glow

    # Nix related tools
    # Provides the command `nom` which works just like `nix`
    # with more detailed log output
    nix-output-monitor
  ];
}
