# nixcfg - my nixos infra

# TODO
- [ ] More documentation, screenshots, comments, etc
- [ ] Unify Tungsten & Uranium disko config (or split into single/dual SSD btrfs luks options)
- [X] Add Carbon and Helium
  - [ ] Copyparty
  - [ ] PDS
  - [ ] Immich
  - [ ] Grafana
  - [ ] www.taxborn.com
  - [X] Paperless-ngx
  - [X] Forgejo
    - [X] Forgejo runners (docker and nixos)
    - [ ] Tangled.sh mirroring
      - [ ] Tangled.sh knot
    - [ ] Github Mirroring
    *Forgejo will be the "source of truth" for my code, and I will mirror that out to Tangled.sh and Github, with tangled also getting a self-hosted actions runner. Github is starting to charge so no CI there.*
  - [X] Glance
  - [X] Vaultwarden
- [ ] Snippet-ify where needed

# Acknowledgements
This is heavily derived from [Aly Ruffauf's configuration](https://github.com/alyraffauf/nixcfg).
