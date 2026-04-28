{ self, ... }:
{
  age = {
    identityPaths = [ "/home/taxborn/.config/age/yubikey-identity.txt" ];

    secrets = {
      tailscaleAuthKey.file = "${self.inputs.secrets}/tailscale/auth.age";
    };
  };
}
