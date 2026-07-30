{
  lib,
  ...
}:
{
  options.mySnippets.ssh = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 2022;
      description = ''
        Port every host's sshd answers, and the port the client config
        addresses those hosts on.

        Not 22, and for the same reason the borg port is not 22: where
        Tailscale SSH is enabled, tailscaled answers port 22 on the tailnet
        address itself and sshd never sees the connection. Its SSH server
        forwards an agent fine, but it does not implement unix-socket remote
        forwarding (tailscale/tailscale#6232), so the GPG socket forward fails
        there with `remote port forwarding failed for listen path`. Tailscale
        intercepts only 22, so any other port reaches real sshd, where both
        forwards work.

        Leaving 22 to Tailscale SSH rather than turning it off is the point:
        it stays as a way into a host by tailnet identity when the yubikey is
        not available, which is the one failure mode this whole arrangement
        makes more likely.

        Declared here because three places need the same number and a mismatch
        between any two of them is a connection failure: sshd, the client
        `Port`, and `knownHosts` — ssh records a non-default port as
        `[host]:port`, so the bracketed entry has to agree as well.
      '';
    };

    gnupgSocketDir = lib.mkOption {
      type = lib.types.str;
      default = "/run/user/1000/gnupg";
      description = ''
        Directory holding the gpg-agent sockets, on both ends of a forward.

        Hardcoded rather than derived because both ends need it at build time:
        the client writes the path into `RemoteForward` and the target creates
        the directory. 1000 is taxborn's uid, pinned in
        `modules/users/taxborn.nix` — gnupg puts its sockets under
        `$XDG_RUNTIME_DIR` whenever the homedir is the default one, and that is
        `/run/user/<uid>`.
      '';
    };
  };
}
