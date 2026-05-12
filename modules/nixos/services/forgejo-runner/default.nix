{
  config,
  lib,
  pkgs,
  self,
  utils,
  ...
}:
{
  options.myNixOS.services.forgejo-runner = {
    enable = lib.mkEnableOption "Forĝejo runners";

    nativeRunners = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "How many native NixOS runners to run for the Forĝejo runner.";
    };

    dockerContainers = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "How many docker containers to run for the Forĝejo runner.";
    };
  };

  config = lib.mkIf config.myNixOS.services.forgejo-runner.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "We contact Forĝejo over tailscale, but services.tailscale.enable != true.";
      }
    ];

    age.secrets.act-runner.file = "${self.inputs.secrets}/forgejo/runner-key.age";

    users.users.gitea-runner = {
      isSystemUser = true;
      group = "gitea-runner";
    };
    users.groups.gitea-runner = {};

    systemd.services = lib.mapAttrs' (name: _:
      lib.nameValuePair "gitea-runner-${utils.escapeSystemdPath name}" {
        serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = lib.mkForce "gitea-runner";
          Group = lib.mkForce "gitea-runner";
        };
      }
    ) config.services.gitea-actions-runner.instances;

    services.gitea-actions-runner = {
      instances =
        let
          tokenFile = config.age.secrets.act-runner.path;
        in
        {
          taxborn-containers = {
            inherit tokenFile;
            enable = true;

            labels = [ "ubuntu-latest:docker://gitea/runner-images:ubuntu-latest" ];

            name = "x86_64_linux-${config.networking.hostName}-taxborn-containers";

            settings = {
              container.network = "host";
              runner.capacity = config.myNixOS.services.forgejo-runner.dockerContainers;
            };

            url = "http://${config.mySnippets.mischief-town.networkMap.forgejo.internalHost}:${toString config.mySnippets.mischief-town.networkMap.forgejo.port}";
          };

          taxborn-nixos = {
            inherit tokenFile;
            enable = true;

            hostPackages =
              with pkgs;
              [
                bash
                cachix
                coreutils
                curl
                gawk
                gitMinimal
                gnused
                jq
                nodejs
                wget
              ]
              ++ [ config.nix.package ];

            labels = [ "nixos-x86_64_linux:host" ];
            name = "x86_64_linux-${config.networking.hostName}-taxborn-nixos";

            settings = {
              container.network = "host";
              runner.capacity = config.myNixOS.services.forgejo-runner.nativeRunners;
            };

            url = "http://${config.mySnippets.mischief-town.networkMap.forgejo.internalHost}:${toString config.mySnippets.mischief-town.networkMap.forgejo.port}";
          };
        };
    };
  };
}
