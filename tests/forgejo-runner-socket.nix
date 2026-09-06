{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "forgejo-runner-socket";
  nodes.machine =
    { config, lib, ... }:
    {
      imports = [ ../modules/nixos/services/forgejo-runner/default.nix ];

      # Supply the fleet-only options without importing unrelated services
      # or any host's encrypted credentials into this disposable VM.
      options = {
        myNixOS.services.forgejo.enable = lib.mkEnableOption "forge";
        myNixOS.services.backups = {
          server.enable = lib.mkEnableOption "backup server";
          client = {
            enable = lib.mkEnableOption "backup client";
            extraExcludes = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
          };
        };
        mySnippets.biscuits-at.networkMap = lib.mkOption {
          default.forgejo.domain = "unused.example";
        };
      };

      config = {
        myNixOS.services.forgejo-runner.enable = true;
        virtualisation.memorySize = 1536;
        systemd.services.forgejo-runner.serviceConfig = {
          # Exercise the production sandbox against a real rootless Podman
          # API, without requiring a Forgejo instance or real registration.
          ExecStart = lib.mkForce (
            pkgs.writeShellScript "probe-runner-socket" ''
              set -eu
              test ! -e /home/private-marker
              ${lib.getExe pkgs.curl} --fail --unix-socket /run/user/990/podman/podman.sock http://localhost/_ping
            ''
          );
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = lib.mkForce "no";
        };
        systemd.services.broken-runner = {
          serviceConfig = config.systemd.services.forgejo-runner.serviceConfig // {
            ProtectHome = true;
            BindReadOnlyPaths = [ ];
            ExecStartPre = [ ];
            LoadCredential = [ ];
            RuntimeDirectory = "broken-runner";
          };
        };
      };
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_file("/run/user/990/podman/podman.sock")
    machine.succeed("touch /home/private-marker")
    machine.fail("systemctl is-active forgejo-runner")
    machine.succeed("install -m 0600 /dev/null /var/lib/forgejo-runner-credentials/connection.json")
    machine.succeed("printf '%s' '{\"uuid\":\"test-uuid\",\"token\":\"test-token\"}' > /var/lib/forgejo-runner-credentials/connection.json")
    with subtest("old sandbox blocks the socket"):
        machine.fail("systemctl start broken-runner")
        machine.succeed("systemctl is-failed broken-runner")
    with subtest("runner reaches rootless Podman while homes remain hidden"):
        machine.succeed("systemctl start forgejo-runner")
        machine.wait_for_unit("forgejo-runner.service")
        machine.succeed("test -S /run/user/990/podman/podman.sock")
        machine.fail("systemctl is-active podman.socket")
  '';
}
