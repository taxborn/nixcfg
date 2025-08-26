{ pkgs, inputs, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  # Web browsers
  programs.zen-browser.enable = true;

  # Text editors and IDEs
  programs.zed-editor = {
    enable = true;
    extensions = [ "nix" ];
  };

  # Additional GUI applications can be added here
  home.packages = with pkgs; [
    # Add other GUI applications as needed
  ];
}
