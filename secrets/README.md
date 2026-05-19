# secrets

agenix-encrypted secrets for the nix-infra configuration.

## how it works

[agenix](https://github.com/ryantm/agenix) encrypts secrets with age using SSH public keys. each secret is encrypted for specific hosts and users, defined in `secrets.nix`. only machines with the corresponding private key can decrypt their secrets at activation time.

## provisioning a new secret
1. name the secret in [secrets.nix](./secrets.nix)
  ```nix
  "tailscale/auth.age".publicKeys = keys;
  ```
2. then create the secret with `agenix -e tailscale/auth.age -i ~/.config/age/yubikey-identity.txt`
3. then use the key (check wiki/docs to determine if you need an env var setup or not):
  ```nix
  secrets = {
    tailscaleAuthKey.file = "${self}/secrets/tailscale/auth.age";
  };
  ```
## provisioning a new system
1. copy `/etc/ssh/ssh_host_ed25519_key.pub` to `./publicKeys` under the name root_`<hostname>`.pub.
2. rekey the secrets on a host that either has access to the Yubikey or already provisioned
  `agenix -r -i ~/.config/age/yubikey-identity.txt`
