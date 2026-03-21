# Update the local NixOS system
update:
    sudo nixos-rebuild switch --flake

restart-web host website:
    ssh -t {{host}} sudo systemctl restart podman-{{website}}.service

# Deploy to a target host (e.g. `just deploy carbon`)
deploy host:
    sudo nixos-rebuild switch --flake .#{{host}} --target-host {{host}} --sudo

# Remove all old nix generations
clean:
    sudo nix-collect-garbage -d
