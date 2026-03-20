{ self, ... }:
{
  age.secrets = {
    tailscaleAuthKey.file = "${self.inputs.secrets}/tailscale/auth.age";
    hash-haus.file = "${self.inputs.secrets}/hash-haus.age";
  };
}
