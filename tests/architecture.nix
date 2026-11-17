{ self, lib }:
let
  validNetwork =
    value:
    (builtins.tryEval (
      builtins.deepSeq
        (lib.evalModules {
          modules = [
            ../modules/options.nix
            { homelab.services = lib.mkForce { test = value; }; }
          ];
          specialArgs = { inherit self; };
        }).config.homelab.services
        true
    )).success;
  argon = self.nixosConfigurations.argon;
  extend = modules: (argon.extendModules { inherit modules; }).config;
  failures = config: map (a: a.message) (builtins.filter (a: !a.assertion) config.assertions);
  wrongRecipient = extend [
    {
      age.secrets.wrongRecipient.file = "${self}/secrets/paperless.age";
    }
  ];
  movedPaths = extend [
    {
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
  testSpindleRejectsBackupHost = {
    expr = builtins.elem "Keep CI jobs off the fleet's backup server." (
      failures
        (self.nixosConfigurations.helium.extendModules {
          modules = [ ../modules/nixos/services/tangled/spindle.nix ];
        }).config
    );
    expected = true;
  };
  testWrongSecretRecipient = {
    expr = builtins.elem "argon: age secret wrongRecipient must exist and its rule must include this host and the recovery YubiKey." (
      failures wrongRecipient
    );
    expected = true;
  };
  testDumpsFollowServicePaths = {
    expr = lib.mapAttrs (
      _: repo: map (db: { inherit (db) name path; }) repo.sqlite_databases
    ) movedPaths.services.borgmatic.configurations;
    expected = lib.genAttrs [ "rsync" "helium" ] (_: [
      {
        name = "tealfm-piper";
        path = "/var/lib/tealfm-piper/moved.db";
      }
      {
        # a fixed path, so it does not move with piper's
        name = "vaultwarden";
        path = "/var/lib/vaultwarden/db.sqlite3";
      }
    ]);
  };
}
