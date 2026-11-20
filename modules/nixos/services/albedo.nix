{
  config,
  pkgs,
  self,
  ...
}:
let
  inherit (config.homelab) owner;
  inherit (config.homelab.services) albedo knot;
  inherit (config.networking) hostName;
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

  homelab.backups.extraExcludes = [ "${home}/.albedo" ];

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

      programs = {
        albedo.enable = true;

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

      services.albedo.enable = true;

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
