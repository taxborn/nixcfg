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
   git clone https://code.taxborn.com/taxborn/nixcfg && cd nixcfg
   ```
4. Format the disk using disko:
   ```bash
   sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko hosts/tungsten/disks.nix
   ```
5. Install NixOS:
   ```bash
   sudo nixos-install --flake .#tungsten --root /mnt
   ```

# TODO
- [ ] More Hyprland configuration
- [ ] Screenshots
- [ ] Figure out gpg-agent forwarding? maybe only SSH forwarding?
  I think I want to be able to code on my headless machines (carbon/helium). For that I currently need to
  forward my GPG agent since I sign code with my PGP key. If I switch to signing with my SSH key, I can probably
  just forward my SSH agent instead.
- [ ] Add more documentation about everything
- [ ] Keychron VIA config on Uranium
- [ ] Spend a bit of time to figure good config values
    - [ ] SSH
    - [ ] Boot
    - [ ] Kernel
