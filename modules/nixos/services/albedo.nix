{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (config.homelab) owner;
  inherit (config.homelab.services) albedo knot;
  inherit (config.networking) hostName;
  inherit (config.homelab) monitoring backupServer;

  # Loopback ports of everything else on this host. Albedo's own daemon port is ephemeral.
  blockedPorts = lib.unique (
    lib.attrValues monitoring.ports
    ++ [ backupServer.port ]
    ++ lib.mapAttrsToList (_: svc: svc.port) (lib.removeAttrs config.homelab.services [ "albedo" ])
  );
  chain = "agent-egress";
  rule = ip: "${ip} -w -C OUTPUT -m owner --uid-owner ${user} -j ${chain}";
  email = "${user}@${config.homelab.domain}";
  user = "agent";
  home = config.users.users.${user}.home;
  signingKey = "${home}/.ssh/id_ed25519_signing";
in
{
  users.users.${user} = {
    isNormalUser = true;
    linger = true;
    description = "${owner.name}'s coding agent";
    openssh.authorizedKeys.keyFiles = [ "${self}/keys/yubikey.pub" ];
  };

  programs.ssh.knownHosts.knot = {
    hostNames = [ "[${knot.sshDomain}]:${toString knot.sshPort}" ];
    publicKeyFile = "${self}/keys/knot_argon.pub";
  };

  networking.firewall = {
    extraCommands =
      lib.concatMapStrings
        (ip: ''
          ${ip} -w -N ${chain} 2>/dev/null || ${ip} -w -F ${chain}
          ${lib.concatMapStrings (port: ''
            ${ip} -w -A ${chain} -o lo -p tcp --dport ${toString port} -j REJECT --reject-with tcp-reset
          '') blockedPorts}
          ${rule ip} 2>/dev/null || ${ip} -w -I OUTPUT -m owner --uid-owner ${user} -j ${chain}
        '')
        [
          "iptables"
          "ip6tables"
        ];

    extraStopCommands =
      lib.concatMapStrings
        (ip: ''
          ${ip} -w -D OUTPUT -m owner --uid-owner ${user} -j ${chain} 2>/dev/null || true
          ${ip} -w -F ${chain} 2>/dev/null || true
          ${ip} -w -X ${chain} 2>/dev/null || true
        '')
        [
          "iptables"
          "ip6tables"
        ];
  };

  homelab.backups = {
    sqliteDatabases.albedo = "${home}/.albedo/albedo.sqlite";
    extraExcludes = [ "${home}/.albedo/backups" ];
  };

  home-manager.users.${user} =
    { config, lib, ... }:
    {
      imports = [ self.inputs.albedo.homeModules.default ];

      home = {
        stateVersion = "25.11";
        packages = with pkgs; [
          fd
          gh
          jq
          just
          self.packages.${pkgs.stdenv.hostPlatform.system}.tg
          tmux
          ripgrep
        ];

        activation.agentSigningKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -e ${signingKey} ]; then
            run mkdir -p -m 700 ${home}/.ssh
            run ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C "${user}@${hostName}" -f ${signingKey}
          fi
          run mkdir -p ${home}/.config/git
          [ -v DRY_RUN ] || printf '%s %s\n' "${email}" "$(cut -d' ' -f1,2 ${signingKey}.pub)" > ${home}/.config/git/allowed_signers
        '';
      };

      xdg.configFile."systemd/user/app.slice.d/limits.conf".text = ''
        [Slice]
        MemoryHigh=12G
        MemoryMax=16G
        TasksMax=8192
        CPUWeight=50
        IOWeight=50
      '';

      programs = {
        albedo.enable = true;

        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };

        jujutsu = {
          enable = true;
          settings = {
            user = {
              name = "${owner.name} (agent)";
              inherit email;
            };
            signing = {
              behavior = "own";
              backend = "ssh";
              key = "${signingKey}.pub";
              backends.ssh.allowed-signers = "${home}/.config/git/allowed_signers";
            };
          };
        };

        git = {
          enable = true;
          signing = {
            format = "ssh";
            key = signingKey;
            signByDefault = true;
          };
          settings = {
            user = {
              name = "${owner.name} (agent)";
              inherit email;
            };
            gpg.ssh.allowedSignersFile = "${home}/.config/git/allowed_signers";
            init.defaultBranch = "main";
            url."https://tangled.org/".insteadOf = "git@tangled.org:";
            url."tangled:".pushInsteadOf = "git@tangled.org:";
          };
        };

        ssh = {
          enable = true;
          enableDefaultConfig = false;
          settings.tangled = {
            Hostname = knot.sshDomain;
            User = "git";
            Port = knot.sshPort;
            IdentityFile = signingKey;
            IdentitiesOnly = "yes";
          };
        };
      };

      services.albedo = {
        enable = true;
        settings.extensions.subagents = {
          maxDepth = 2;
          maxOpenChildren = 4;
        };
      };

      home.file.".agents/instructions.md".text = ''
        # Working on this host

        You run as the `agent` user on Helium, a homelab server. Paperless and every
        host's second backup copy live here too, so keep builds and test runs modest.
        Do not probe other services on this host or the tailnet.

        - Commit each substantive change, in Conventional Commits, lowercase, with a
          scope naming the service or module. Commits are signed with your own key.
        - Push a branch and never `main`, unless you are asked to.
        - Never write a secret into a file that enters the Nix store, and never read
          `~/.ssh` or `~/.albedo/creds.json`.
        - If `direnv` reports a blocked `.envrc`, tell the user. Do not run
          `direnv allow`.
        - You have no sudo. Do not try to rebuild or switch a system, and do not run
          deploy or restore recipes. Propose them.
        - Give each parallel agent its own worktree, and prefer `jj` for them.
        - Run the repo's own checks before you report work as done.
      '';

      systemd.user.services.albedo-web = {
        Unit = {
          Description = "Albedo web client, behind Caddy";
          After = [ "albedo.service" ];
          Wants = [ "albedo.service" ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = lib.escapeShellArgs [
            "${config.programs.albedo.package}/bin/albedo"
            "web"
            "--foreground"
            "--no-open"
            "--local"
            "--public-url"
            "https://${albedo.domain}"
            "--port"
            (toString albedo.port)
          ];
          Restart = "always";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
