# secrets

agenix-encrypted secrets for the nix-infra configuration.

## how it works

[agenix](https://github.com/ryantm/agenix) encrypts secrets with age using SSH public keys. each secret is encrypted for specific hosts and users, defined in `secrets.nix`. only machines with the corresponding private key can decrypt their secrets at activation time.

## provisioning a new secret
TODO

## provisioning a new system
TODO
