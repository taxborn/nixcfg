{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.forgejo;

  forgejo = config.services.forgejo;

  secretName = name: "forgejoRunner-${name}";
  unitName = name: "forgejo-register-runner-${name}";

  # Everything a runner needs to authenticate is derivable from one 40-character
  # hexadecimal secret, so that secret is the only thing this host and the
  # runner host have to agree on.
  #
  # Forgejo splits it in two. The first 16 characters are an identifier: it
  # takes those characters as raw bytes and reads them as a UUID
  # (`gouuid.FromBytes([]byte(token[:16]))` in models/actions/forgejo.go), which
  # is how registering the same secret twice updates one runner instead of
  # creating a second. The remaining 24 are the password half, stored salted and
  # hashed. Neither side ever has to be told the UUID, because both can compute
  # it — the runner does exactly that in runner.nix.
  registerScript =
    name: runner:
    pkgs.writeShellScript (unitName name) ''
      set -euo pipefail

      # `--secret-file` wants exactly 40 characters and validates the length
      # before anything else, so the newline an editor leaves at the end of an
      # agenix file makes it 41 and fails the run. Strip whitespace into the
      # unit's own tmpfs rather than asking every future secret to be written
      # without a trailing newline.
      secret="$RUNTIME_DIRECTORY/secret"
      tr -d '[:space:]' < "$CREDENTIALS_DIRECTORY/secret" > "$secret"

      # Idempotent by design: RegisterRunner looks the runner up by the UUID
      # derived from the secret, creates it when absent, and rewrites the stored
      # hash only when the secret has actually changed. Running it on every boot
      # and every activation is the intended usage.
      #
      # --keep-labels leaves `agent_labels` alone. The runner declares its own
      # labels to Forgejo on each daemon start, so passing them here as well
      # would mean two places to edit for one change — and the runner would win
      # anyway. Without the flag an empty --labels would overwrite the list with
      # a single empty label until the next declaration repaired it.
      exec ${lib.getExe' forgejo.package "forgejo"} forgejo-cli actions register \
        --name ${lib.escapeShellArg name} \
        --scope ${lib.escapeShellArg (if runner.scope == null then "" else runner.scope)} \
        --keep-labels \
        --secret-file "$secret"
    '';

  mkRegisterUnit = name: runner: {
    description = "Register the ${name} Forgejo Actions runner";

    # forgejo-cli talks to the database directly rather than over HTTP, so this
    # does not need the web server to be answering — but it does need the
    # schema, and on an upgrade boot Forgejo is the thing applying migrations.
    # Ordering after it, and retrying, covers the window.
    requires = [ "forgejo.service" ];
    after = [ "forgejo.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.coreutils ];

    environment = {
      HOME = forgejo.stateDir;
      FORGEJO_WORK_DIR = forgejo.stateDir;
      FORGEJO_CUSTOM = forgejo.customDir;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      # The same user Forgejo runs as, because this opens Forgejo's SQLite
      # database and writes to it. Concurrent with the running server, which is
      # safe here only because `database.SQLITE_JOURNAL_MODE = "WAL"` is set in
      # default.nix — under the rollback journal this would contend with live
      # traffic for the write lock.
      User = forgejo.user;
      Group = forgejo.group;
      UMask = "0077";

      RuntimeDirectory = unitName name;
      RuntimeDirectoryMode = "0700";
      LoadCredential = [ "secret:${config.age.secrets.${secretName name}.path}" ];

      ExecStart = registerScript name runner;

      Restart = "on-failure";
      RestartSec = 10;
    };
  };
in
{
  options.myNixOS.services.forgejo.runners = lib.mkOption {
    default = { };
    example = lib.literalExpression ''
      {
        argon = { };
        helium.scope = "taxborn";
      }
    '';
    description = ''
      Forgejo Actions runners to register against this instance, keyed by the
      hostname of the machine that will run them.

      Registration is offline: each name here needs a 40-character hexadecimal
      secret at `secrets/forgejo/runner-<name>.age`, readable by this host and
      by the runner's host. Generate one with `openssl rand -hex 20`. Nothing
      has to be minted from the web UI, and nothing is copied back out of it —
      see the comment above `registerScript` for why the secret is sufficient
      on its own.

      Removing a name here stops this host from asserting the runner's
      existence, but does not delete it: the row stays in the database and the
      runner keeps showing up under `/admin/actions/runners` until it is
      deleted there.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.scope = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "taxborn/nix";
          description = ''
            `{owner}` or `{owner}/{repo}`, limiting the runner to workflows in
            repositories under that owner or in that single repository. `null`
            registers an instance-wide runner, which can pick up a job from any
            repository here.

            Instance-wide is the right answer only for as long as every account
            on this instance is trusted, which is what
            `service.DISABLE_REGISTRATION` in default.nix is holding up. If that
            ever opens, this is the setting that keeps a stranger's repository
            from finding a runner.
          '';
        };
      }
    );
  };

  config = lib.mkIf (cfg.enable && cfg.runners != { }) {
    age.secrets = lib.mapAttrs' (
      name: _:
      lib.nameValuePair (secretName name) {
        file = "${self}/secrets/forgejo/runner-${name}.age";
      }
    ) cfg.runners;

    systemd.services = lib.mapAttrs' (
      name: runner: lib.nameValuePair (unitName name) (mkRegisterUnit name runner)
    ) cfg.runners;
  };
}
