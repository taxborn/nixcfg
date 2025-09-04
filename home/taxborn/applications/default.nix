{ pkgs, inputs, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.beta

    ./zed.nix
  ];

  # Web browsers
  programs.zen-browser.enable = true;

  # Additional GUI applications can be added here
  home.packages = with pkgs; [
    # Add other GUI applications as needed
  ];
}
