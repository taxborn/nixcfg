{ self, lib }:
let
  validNetwork =
    value:
    (builtins.tryEval (
      builtins.deepSeq
        (lib.evalModules {
          modules = [
            ../modules/snippets/networkMap.nix
            ../modules/snippets/tailscale.nix
            { mySnippets.biscuits-at.networkMap = lib.mkForce { test = value; }; }
          ];
        }).config.mySnippets.biscuits-at.networkMap
        true
    )).success;
  argon = self.nixosConfigurations.argon;
  extend = modules: (argon.extendModules { inherit modules; }).config;
  failures = config: map (a: a.message) (builtins.filter (a: !a.assertion) config.assertions);
  missingTailnet = extend [
    ({ config, ... }: {
      mySnippets.tailnet.tailscaleIPs = lib.mkForce (
        builtins.removeAttrs argon.config.mySnippets.tailnet.tailscaleIPs [ "carbon" ]
      );
      # Keep fail2ban's own checks from masking the fleet assertion under test.
      services.fail2ban.ignoreIP = lib.mkForce (
        builtins.attrValues config.mySnippets.tailnet.tailscaleIPs
      );
    })
  ];
  wrongRecipient = extend [
    {
      age.secrets.wrongRecipient.file = "${self}/secrets/paperless.age";
    }
  ];
  backupDisabled = extend [
    {
      myNixOS.services.backups.client.enable = lib.mkForce false;
    }
  ];
  movedPaths = extend [
    {
      services.forgejo.database.path = "/var/lib/forgejo/moved.db";
      services.tealfm-piper.settings.DB_PATH = "/var/lib/tealfm-piper/moved.db";
    }
  ];
  movedRepositories = extend [
    {
      myNixOS.services.backups.client.repositories.rsync = lib.mkForce {
        label = "rsync";
        path = "ssh://backup@example.test/./moved/argon";
        remotePath = "borg-custom";
      };
    }
  ];
  movedCoverage =
    (import ../modules/flake/restore.nix {
      self.nixosConfigurations.argon.config = movedRepositories;
      inputs.nixpkgs.lib = lib;
    }).flake.restoreCoverage;
in
lib.runTests {
  testRestoreFollowsRepositorySettings = {
    expr = movedCoverage.argon.rsync;
    expected = {
      path = "ssh://backup@example.test/./moved/argon";
      remotePath = "borg-custom";
      tier1 = true;
      tier2 = true;
      reason = null;
    };
  };
  testNetworkSchema = {
    expr = map validNetwork [
      {
        domain = "test.biscuits.at";
        port = 3000;
      }
      {
        domain = "test.biscuits.at";
        port = 3000;
        sshDomain = "argon.test";
        sshPort = 2222;
      }
      { port = 3000; }
      { domain = "test.biscuits.at"; }
      {
        domain = "";
        port = 3000;
      }
      {
        domain = "test.biscuits.at";
        port = "3000";
      }
      {
        domain = "test.biscuits.at";
        port = 0;
      }
      {
        domain = "test.biscuits.at";
        port = 65536;
      }
      {
        domain = "test.biscuits.at";
        port = 3000;
        prot = 3001;
      }
      {
        domain = "test.biscuits.at";
        port = 3000;
        sshPort = 2222;
      }
    ];
    expected = [
      true
      true
      false
      false
      false
      false
      false
      false
      false
      false
    ];
  };
  testFleetAgrees = {
    expr = lib.mapAttrs (_: host: failures host.config) self.nixosConfigurations;
    expected = lib.genAttrs (builtins.attrNames self.nixosConfigurations) (_: [ ]);
  };
  testRunnerPlacement = {
    expr = lib.mapAttrs (
      _: host: host.config.myNixOS.services.forgejo-runner.enable
    ) self.nixosConfigurations;
    expected = {
      argon = false;
      carbon = true;
      helium = false;
      tungsten = false;
      uranium = false;
    };
  };
  testRunnerRejectsForgeHost = {
    expr = builtins.elem "Keep CI jobs off the host holding Forgejo's repositories and credentials." (
      failures (extend [ { myNixOS.services.forgejo-runner.enable = true; } ])
    );
    expected = true;
  };
  testRunnerRejectsBackupHost = {
    expr = builtins.elem "Keep CI jobs off the fleet's backup server." (
      failures
        (self.nixosConfigurations.helium.extendModules {
          modules = [ { myNixOS.services.forgejo-runner.enable = true; } ];
        }).config
    );
    expected = true;
  };
  testMissingTailnetHost = {
    expr = builtins.elem "The NixOS host roster and tailnet map must contain the same hosts." (
      failures missingTailnet
    );
    expected = true;
  };
  testWrongSecretRecipient = {
    expr = builtins.elem "argon: age secret wrongRecipient must exist and its rule must include this host and the recovery YubiKey." (
      failures wrongRecipient
    );
    expected = true;
  };
  testDisabledBackupClient = {
    expr = {
      inherit (backupDisabled.myNixOS.services.backups.client) postgresqlDumpAll sqliteDatabases;
      configurations = backupDisabled.services.borgmatic.configurations;
    };
    expected = {
      postgresqlDumpAll = false;
      sqliteDatabases = { };
      configurations = { };
    };
  };
  testDumpsFollowServicePaths = {
    expr = lib.mapAttrs (
      _: repo: map (db: { inherit (db) name path; }) repo.sqlite_databases
    ) movedPaths.services.borgmatic.configurations;
    expected = lib.genAttrs [ "rsync" "helium" ] (_: [
      {
        name = "forgejo";
        path = "/var/lib/forgejo/moved.db";
      }
      {
        name = "tealfm-piper";
        path = "/var/lib/tealfm-piper/moved.db";
      }
    ]);
  };
}
