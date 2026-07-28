{
  config,
  lib,
  ...
}:
{
  options.mySnippets.mischief-town.networkMap = lib.mkOption {
    type = lib.types.attrs;
    description = "Hostnames, ports, and vHosts for mischief.town services.";

    default = {
      vaultwarden = {
        domain = "vw.mischief.town";
        port = 3000;
      };

      forgejo = {
        domain = "git.mischief.town";
        port = 3001;

        # Git over SSH is tailnet-only, so it is addressed by MagicDNS rather
        # than through the web domain. It has to be a separate name: every
        # mischief.town record is proxied by Cloudflare, whose proxy carries
        # HTTP(S) and nothing else, so an ssh:// URL aimed at the web domain
        # would resolve to a Cloudflare edge and hang rather than reach us.
        #
        # This is the one place clone URLs are decided. Pointing it at a
        # service-scoped record instead (a DNS-only A for the tailnet address)
        # would decouple them from the host, at the cost of publishing a
        # tailnet address in public DNS.
        sshDomain = "carbon.${config.mySnippets.tailnet.name}";

        # Not 22. Tailscale SSH owns port 22 on the tailnet interface and
        # answers it by tailnet identity, which bypasses the forced command
        # Forgejo relies on — so git has to be somewhere Tailscale does not
        # intercept. See the forgejo module.
        sshPort = 2222;
      };
    };
  };
}
