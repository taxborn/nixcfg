# Update the local NixOS system
update:
    sudo nixos-rebuild switch --flake .

# Remove all old nix generations
clean:
    sudo nix-collect-garbage -d
