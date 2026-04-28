{ self, ... }:
{
  age = {
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/home/taxborn/.config/age/yubikey-identity.txt"
    ];

    secrets = {
      tailscaleAuthKey.file = "${self.inputs.secrets}/tailscale/auth.age";
    };
  };
}
