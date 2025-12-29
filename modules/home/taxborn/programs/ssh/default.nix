{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.taxborn.programs.ssh.enable = lib.mkEnableOption "openssh client";

  config = lib.mkIf config.myHome.taxborn.programs.ssh.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks =
        let
          rootMe = name: {
            ${name} = {
              hostname = name;
              user = "root";
            };
          };
        in
        rootMe "tungsten"
        // {
          "*" = {
            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
          };
        };

      package = pkgs.openssh;
    };
  };
}
