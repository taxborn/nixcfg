{
  self,
  pkgs,
  ...
}:
let
  manix = pkgs.symlinkJoin {
    name = "manix-nixpath";
    paths = [ pkgs.manix ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/manix \
        --set NIX_PATH "nixpkgs=${self.inputs.nixpkgs}:home-manager=${self.inputs.home-manager}"
    '';
  };
in
{
  imports = [ self.inputs.nix-index-database.homeModules.nix-index ];

  home.packages = [
    manix
    pkgs.nix-search-tv
  ];

  programs.fish.shellAbbrs.ns = "nix-search-tv print | fzf --scheme=history --height=80% --preview 'nix-search-tv preview {}' --preview-window=wrap";
}
