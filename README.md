# nixcfg - my nixos infra

# Usage

Commands are run from the `nix-infra` root via [`just`](https://github.com/casey/just).

| Command | Description |
|---|---|
| `just update` | Rebuild and switch the local NixOS system |
| `just deploy <host>` | Deploy to a remote host (e.g. `just deploy carbon`) |
| `just deploy-website` | Restart the website on carbon |
| `just clean` | Remove all old Nix generations |

# TODO
- [ ] More documentation, screenshots, comments, etc
- [ ] Unify Tungsten & Uranium disko config (or split into single/dual SSD btrfs luks options)
- [ ] Grafana
- [ ] Tangled.sh mirroring

# Acknowledgements
This is heavily derived from [Aly Raffauf's configuration](https://github.com/alyraffauf/nixcfg).
