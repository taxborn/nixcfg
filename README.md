# nixos homelab configuration

this repository holds my nixos configuration for all of my hosts.

## provisioning a new host

1. create a generic host under [hosts/](./hosts) and add its name to the list in
   [modules/flake/hosts.nix](modules/flake/hosts.nix) (reference commit [138a32e](https://github.com/taxborn/nix/commit/138a32e6aebe9c11ce35fcecd2cd64acafc5337b))
2. enable root login by an SSH key (I'd likely want to use my
   [personal SSH key](./keys/yubikey.pub))) on the host
3. `nix run github:nix-community/nixos-anywhere -- --flake .#<host-name> --target-host root@<ip address>`

## references

- [aly.codes](https://github.com/alyraffauf/nixcfg)'s nixcfg
- [isabelroses.com](https://github.com/isabelroses/dotfiles)'s configuration
