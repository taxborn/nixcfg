_: {
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      font-family = "JetBrainsMono NFM";
      font-size = 12;
      shell-integration = "fish";
      confirm-close-surface = false;
      window-padding-x = 8;
      window-padding-y = 8;
    };
  };
}
