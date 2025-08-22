# Braxton's NixOS setup and dotfiles
This repository serves as the documentation for my NixOS setup, dotfiles, and homelab configuration.

## Installing on a clean machine
Using tungsten as an example, follow these steps:

1. Boot into a NixOS live (graphical or minimal) environment (e.g., a USB drive).
2. Connect to the internet if necessary.
    ```bash
    sudo systemctl start wpa_supplicant.service
    wpa_cli
    # > add_network
    # > set_network 0 ssid "mynetwork"
    # > set_network 0 psk "mypassword"
    # > enable_network 0
    ```
3. Clone this repository into your home directory:
   ```bash
   git clone https://github.com/taxborn/dotfiles.git ~/dotfiles
   ```
4. Format the disk using disko:
   ```bash
   sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko dotfiles/hosts/tungsten/disks.nix
   ```
5. Install NixOS:
   ```bash
   sudo nixos-install --flake .#tungsten --root /mnt
   ```
