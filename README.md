# nixcfg

NixOS flake configuration managing 4 hosts across desktop, laptop, and server environments.

## hosts

| host | role | hardware | boot | notes |
|---|---|---|---|---|
| **uranium** | desktop | intel cpu, amd gpu | lanzaboote (secure boot) | dual monitor, LUKS+FIDO2, gaming (steam) |
| **tungsten** | laptop | intel cpu, nvidia gpu (optimus) | lanzaboote (secure boot) | HiDPI (3456x2160), LUKS+FIDO2 |
| **carbon** | remote server (OVH) | intel cpu | grub | caddy reverse proxy, forgejo, vaultwarden, bluesky PDS, tangled |
| **helium-01** | local homestead server | intel cpu | systemd-boot | immich, paperless, copyparty, grafana + prometheus |

all hosts run tailscale, openssh, borg backups (to rsync.net), and node-exporter for monitoring.

## architecture

the flake uses [flake-parts](https://github.com/hercules-ci/flake-parts) to organize outputs. host configurations are generated with `nixpkgs.lib.genAttrs` across all 4 hosts (see `modules/flake/nixos.nix`).

### module namespaces

- `myNixOS.*` - system-level NixOS modules (base config, desktop, programs, services, profiles)
- `myHome.*` - home-manager modules (desktop, programs, services, profiles)
- `myHome.taxborn.*` - user-specific home-manager modules (git, gpg, firefox, zen, etc.)
- `myHardware.*` - hardware configuration (cpu, gpu, profiles like laptop/ssd/ovh)
- `myUsers.*` - user account definitions
- `mySnippets.*` - shared configuration snippets (from the `snippets` flake input)

### module pattern

every module follows the same structure:

```nix
{ config, lib, ... }:
{
  options.myNixOS.thing.enable = lib.mkEnableOption "thing";
  config = lib.mkIf config.myNixOS.thing.enable {
    # actual configuration
  };
}
```

enable a module in a host config with `myNixOS.thing.enable = true;`.

## directory structure

```
nixcfg/
  flake.nix               # flake inputs and flake-parts entrypoint
  justfile                 # build/deploy commands
  hosts/
    uranium/               # desktop
      default.nix          #   NixOS config (hardware, myNixOS options, boot)
      home.nix             #   home-manager config (packages, myHome options)
      secrets.nix          #   agenix secret declarations
    tungsten/              # laptop (same structure)
    carbon/                # remote server
      proxy.nix            #   caddy virtual host definitions
      secrets.nix          #   agenix secrets (tailscale, lastfm, etc.)
    helium-01/             # homestead server
  homes/
    taxborn/default.nix    # shared taxborn home base (fish, git, gpg, tmux, yubikey)
  modules/
    disko/                 # disk partitioning (LUKS+btrfs for desktops, btrfs for servers)
    flake/                 # flake output definitions (nixosConfigurations, homeModules)
    hardware/              # cpu/gpu drivers, hardware profiles (laptop, ssd, ovh)
    home/                  # home-manager modules
      desktop/hyprland/    #   hyprland window manager config
      profiles/            #   default apps, MIME types
      programs/            #   ghostty, bitwarden, ledger, obs, rofi
      services/            #   hypridle, mako, swaybg, swayosd, waybar
      taxborn/             #   user-specific: firefox, git, gpg, minecraft, ssh, zen, zed-editor
    locale/                # locale/timezone
    nixos/                 # NixOS system modules
      base/                #   core system config (networkmanager, git, htop, swap, bluetooth)
      desktop/hyprland/    #   system-level hyprland setup
      profiles/            #   audio, bluetooth, btrfs, graphical-boot, performance, swap
      programs/            #   firefox, gimp, grub, lanzaboote, neovim, nix, podman, systemd-boot, yubikey
      services/            #   backups, caddy, forgejo, glance, grafana, immich, openssh, paperless,
                           #   pds, sddm, tailscale, tangled-knot, taxborn-com, vaultwarden, etc.
    users/                 # user account definitions and groups
```

## home-manager

home-manager runs as a NixOS module (not standalone). two home module paths exist:

- `homeModules.default` (`modules/home/`) - generic modules available to all users/hosts
- `homeModules.taxborn` (`homes/taxborn/`) - taxborn's shared base config that imports `homeModules.default` and enables git, gpg, tmux, yubikey, fish

desktop hosts (uranium, tungsten) import `homeModules.taxborn` and add host-specific packages and options. server hosts (carbon, helium-01) import `homeModules.default` directly with a minimal config.

## flake inputs

| input | purpose |
|---|---|
| nixpkgs | nixos-unstable channel |
| agenix | secret management |
| copyparty | file sharing service |
| disko | declarative disk partitioning |
| flake-parts | flake output organization |
| home-manager | user environment management |
| lanzaboote | UEFI secure boot |
| tgirlpkgs | additional packages |
| zen-browser | zen browser flake |
| snippets | shared config snippets (network map, ssh known hosts, nix settings) |
| secrets | agenix-encrypted secrets (non-flake input) |
| tangled | tangled.org knot server |

## secrets

secrets are managed with [agenix](https://github.com/ryantm/agenix) in a separate repo (`secrets/`). see `secrets/README.md` for details on creating secrets and adding hosts.

each host has a `secrets.nix` that declares which age-encrypted secrets it needs:

```nix
{ self, ... }:
{
  age.secrets = {
    tailscaleAuthKey.file = "${self.inputs.secrets}/tailscale/auth.age";
  };
}
```

## services overview

### carbon (remote)

| service | description |
|---|---|
| caddy | reverse proxy with automatic TLS for all *.mischief.town subdomains |
| forgejo | git forge (git.mischief.town) |
| forgejo-runner | CI runners (3 docker + 2 native) |
| glance | dashboard (home.mischief.town) |
| PDS | bluesky personal data server |
| tangled-knot | tangled.org knot server |
| taxborn-com | personal website (www.taxborn.com) |
| vaultwarden | password manager (vw.mischief.town) |

### helium-01 (homestead)

| service | description |
|---|---|
| caddy | local reverse proxy |
| copyparty | file sharing |
| grafana | monitoring dashboards with prometheus (scrapes all 4 hosts) |
| immich | photo management |
| paperless | document management |
| forgejo-runner | CI runners (3 docker + 2 native) |

### all hosts

| service | description |
|---|---|
| borgbackup | daily encrypted backups to rsync.net |
| tailscale | mesh VPN |
| node-exporter | prometheus metrics |
| openssh | remote access |

## usage

commands are run from the `nix-infra` root via [`just`](https://github.com/casey/just):

| command | description |
|---|---|
| `just update` | rebuild and switch the local NixOS system |
| `just deploy <host>` | deploy to a remote host (e.g. `just deploy carbon`) |
| `just deploy-website` | restart the website container on carbon |
| `just clean` | remove all old nix generations |

## acknowledgements

heavily derived from [Aly Raffauf's configuration](https://github.com/alyraffauf/nixcfg).
