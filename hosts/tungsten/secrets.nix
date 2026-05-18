{ self, ... }:
{
  age = {
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];

    secrets = {
      tailscaleAuthKey.file = "${self}/secrets/tailscale/auth.age";
    };
  };
}
