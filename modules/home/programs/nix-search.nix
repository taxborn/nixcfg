{
  self,
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.myHome.programs.nix-search;

  # manix resolves `<nixpkgs>` and `<home-manager>` through the Nix search path
  # rather than through a flake, and nothing here uses channels. Left alone on
  # these machines it fails to build its NixOS and home-manager caches and falls
  # through to the nix-darwin option set, which is worse than useless: it answers
  # `services.openssh.enable` with Darwin's defaults and never says so. Pointing
  # it at this flake's own inputs both fixes that and keeps its answers matching
  # what a rebuild would actually do.
  #
  # The cache under ~/.cache/manix is not keyed on these paths, so it does not
  # notice a flake update on its own -- `manix -u` after one.
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

  options.myHome.programs.nix-search.enable =
    lib.mkEnableOption "nixpkgs, NixOS and home-manager search tooling";

  config = lib.mkMerge [
    {
      # Importing the database module above is what makes nix-locate usable at
      # all, but it also switches `programs.nix-index` on with `mkDefault`. This
      # file reaches every home through `homeModules.default`, so it takes a
      # plain definition here to outrank that default and keep the ~100 MiB
      # index out of the servers' closures.
      programs.nix-index.enable = cfg.enable;
    }

    (lib.mkIf cfg.enable {
      home.packages = [
        manix
        pkgs.nix-search-tv
      ];

      # nix-search-tv is an indexer and a previewer, not a picker -- fzf is the
      # front end, so the pipeline is the command. An abbreviation rather than a
      # function so it arrives on the command line editable: prepend a
      # `--query nixos/` to start narrowed, or drop the preview to page the raw
      # list. First run indexes nixpkgs, NixOS, home-manager and NUR into
      # ~/.cache/nix-search-tv, which takes about twenty seconds.
      #
      # --height overrides the 30% set in fzf.nix, too short to show an option's
      # type, default and example at once, and the preview wraps because option
      # types run well past half a terminal (the PermitRootLogin enum is 91
      # columns on its own).
      programs.fish.shellAbbrs.ns = "nix-search-tv print | fzf --scheme=history --height=80% --preview 'nix-search-tv preview {}' --preview-window=wrap";
    })
  ];
}
