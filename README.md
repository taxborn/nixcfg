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

# TODO
- [ ] Install on Helium (both)
- [X] Slim down `taxborn` user configuration on headless machines
- [ ] borg/borgmatic backup
- [ ] Hyprland configuration
  - [ ] Kinda figure the feel I want here
  - [ ] Simplify waybar configuration
  - [ ] `wofi` configuration and personalization
  - [ ] Figure out everything I can customize
  - [ ] Ensure things look good on different screens
- [ ] Screenshots
- [ ] Figure out gpg-agent forwarding? maybe only SSH forwarding?
  I think I want to be able to code on my headless machines (carbon/helium). For that I currently need to
  forward my GPG agent since I sign code with my PGP key. If I switch to signing with my SSH key, I can probably
  just forward my SSH agent instead.
- [ ] Add more documentation about everything
  - [ ] `nixos-anywhere` steps on OVH (might be worth a leafpub/blog post?)
- [ ] Spend a bit of time to figure good config values
    - [ ] SSH
    - [ ] Boot
    - [ ] Kernel
