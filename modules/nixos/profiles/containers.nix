{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.profiles.containers.enable = lib.mkEnableOption "rootless container runtime";

  config = lib.mkIf config.myNixOS.profiles.containers.enable {
    virtualisation.podman = {
      enable = true;

      # Puts a `docker` shim on PATH for tooling that shells out to it. Rootless
      # podman runs as the invoking user with no daemon, so unlike docker there
      # is no group whose members are effectively root.
      dockerCompat = true;

      # Podman's default bridge ships with DNS off, so containers on a
      # user-defined network cannot resolve each other by name -- which is the
      # one thing every compose file assumes works.
      defaultNetwork.settings.dns_enabled = true;

      # Image layers accumulate faster than anything else here, and nix's own
      # gc.options only ever touches the nix store.
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    environment.systemPackages = with pkgs; [ podman-compose ];
  };
}
