{ self, lib }:
let
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
in
lib.runTests {
  testFleetAgrees = {
    expr = lib.mapAttrs (_: host: failures host.config) self.nixosConfigurations;
    expected = lib.genAttrs (builtins.attrNames self.nixosConfigurations) (_: [ ]);
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
