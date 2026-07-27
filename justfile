# Update a NixOS system (local by default, or HOST for a remote deploy)
update host="":
    #!/usr/bin/env bash
    if [ -z "{{host}}" ]; then
        sudo nixos-rebuild switch --flake .
    else
        NIX_SSHOPTS="-o RemoteCommand=none -o RequestTTY=no" \
            nixos-rebuild switch --flake .#{{host}} --target-host {{host}} --ask-sudo-password
    fi

# Remove all old nix generations
clean:
    sudo nix-collect-garbage -d
