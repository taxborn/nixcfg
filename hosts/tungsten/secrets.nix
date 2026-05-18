{ self, ... }:
{
  age = {
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/home/taxborn/.config/age/yubikey-identity.txt"
    ];
  };
}
