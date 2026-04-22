# Update the local NixOS system
update:
    sudo nixos-rebuild switch --flake

restart-web host website:
    ssh -t {{host}} sudo systemctl restart podman-{{website}}.service

# Deploy to a target host (e.g. `just deploy carbon`)
deploy host:
    sudo nixos-rebuild switch --flake .#{{host}} --target-host {{host}} --sudo

# Bootstrap a host from scratch via nixos-anywhere (e.g. `just install argon root@1.2.3.4`)
install host target:
    nix run github:nix-community/nixos-anywhere -- \
        --flake .#{{host}} \
        --target-host {{target}}

# Remove all old nix generations
clean:
    sudo nix-collect-garbage -d
