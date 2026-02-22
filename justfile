# Update the local NixOS system
update:
    sudo nixos-rebuild switch --flake

# Restart the website on carbon
deploy-website:
    ssh carbon sudo systemctl restart podman-taxborn-com.service

# Deploy to a target host (e.g. `just deploy carbon`)
deploy host:
    sudo nixos-rebuild switch --flake .#{{host}} --target-host {{host}} --sudo

# Remove all old nix generations
clean:
    sudo nix-collect-garbage -d
