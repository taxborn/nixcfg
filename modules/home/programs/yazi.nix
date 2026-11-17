_: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableFishIntegration = true;
    settings.manager.git_show = true;
  };

  programs.fish.interactiveShellInit = ''
    bind \co y
  '';
}
