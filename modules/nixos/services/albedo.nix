{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (config.homelab) owner;
  inherit (config.networking) hostName;
  port = config.homelab.albedo.port;
  inherit (config.services.tailscale) package;
  email = "${user}@${config.homelab.domain}";
  user = "agent";
  home = config.users.users.${user}.home;
  signingKey = "${home}/.ssh/id_ed25519_signing";
  tailnetV4 = lib.filter (range: !lib.hasInfix ":" range) config.homelab.tailnet.ranges;
in
{
  users.users.${user} = {
    isNormalUser = true;
    linger = true;
    description = "${owner.name}'s coding agent";
    openssh.authorizedKeys.keyFiles = [ "${self}/keys/yubikey.pub" ];
  };

  services.tailscale.extraSetFlags = [ "--operator=${user}" ];

  homelab.backups.extraExcludes = [ "${home}/.albedo" ];

  home-manager.users.${user} =
    { config, lib, ... }:
    {
      imports = [ self.inputs.albedo.homeModules.default ];

      home = {
        stateVersion = "25.11";
        packages = with pkgs; [
          fd
          jq
          package
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
          };
        };
      };

      services.albedo.enable = true;

      systemd.user.services.albedo-web = {
        Unit = {
          Description = "Albedo web client, tailnet only";
          After = [ "albedo.service" ];
          Wants = [ "albedo.service" ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = lib.escapeShellArgs (
            [
              "${config.programs.albedo.package}/bin/albedo"
              "web"
              "--foreground"
              "--no-open"
              "--tailnet-https"
              "--port"
              (toString port)
            ]
            ++ lib.concatMap (range: [
              "--allow"
              range
            ]) tailnetV4
          );
          Restart = "always";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
