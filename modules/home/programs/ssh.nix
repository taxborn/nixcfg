{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.ssh.enable = lib.mkEnableOption "openssh user configuration";

  config = lib.mkIf config.myHome.programs.ssh.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings =
        let
          tailscaleIPs = config.mySnippets.tailnet.tailscaleIPs;
          inherit (config.mySnippets.ssh) gnupgSocketDir;

          machine = name: ip: {
            ${name} = {
              Hostname = ip;
              User = "taxborn";
              # Not 22: that is Tailscale SSH, which cannot carry the socket
              # forward below. See `mySnippets.ssh.port`.
              Port = config.mySnippets.ssh.port;
              # RequestTTY = "yes";
              # RemoteCommand = "tmux new -As0";

              # The yubikey, on every host I log into. Agent forwarding covers
              # ssh — the remote sees an agent holding the card's key, so
              # hopping onward works and git over ssh works.
              ForwardAgent = true;

              # And this covers gpg: the remote's agent socket is this host's
              # *extra* socket, so gpg there signs and decrypts through the card
              # here, and the pinentry prompt appears here rather than on a
              # machine that has no card to prompt about. The extra socket is
              # the restricted one — signing and decryption yes, key management
              # no — which is the whole difference between forwarding the card
              # and handing the remote host the keyring.
              #
              # Nothing is copied: only `keys/pgp.asc` is on the far end, and
              # gpg finds the secret half by asking the agent, which is this
              # one. There is no private key on the remote to leave behind.
              RemoteForward = "${gnupgSocketDir}/S.gpg-agent ${gnupgSocketDir}/S.gpg-agent.extra";
            };
          };

          machines = lib.foldlAttrs (
            acc: name: ip:
            acc // machine name ip
          ) { } tailscaleIPs;
        in
        machines
        // {
          rsync-backup = {
            Hostname = "de4388.rsync.net";
            User = "de4388";
          };
        };
    };
  };
}
