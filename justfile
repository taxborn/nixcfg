# Update the local NixOS system
update:
    sudo nixos-rebuild switch --flake

# Restart the website on carbon
deploy-website:
    ssh carbon sudo systemctl restart podman-taxborn-com.service

# Deploy to a target host (e.g. `just deploy carbon`)
deploy host:
    sudo nixos-rebuild switch --flake .#{{host}} --target-host {{host}} --use-remote-sudo
