{ self, ... }:
{
  age.secrets = {
    tailscaleAuthKey.file = "${self.inputs.secrets}/tailscale/auth.age";
    lastfm.file = "${self.inputs.secrets}/lastfm.age";
  };
}
