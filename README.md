# nixos homelab configuration

this repository holds my nixos configuration for all of my hosts.

## provisioning a new host

1. create a generic host under [hosts/](./hosts) and add its name to the list in
   [modules/flake/hosts.nix](modules/flake/hosts.nix) (reference commit [138a32e](https://git.mischief.town/taxborn/nix/commit/138a32e6aebe9c11ce35fcecd2cd64acafc5337b))
2. enable root login by an SSH key (I'd likely want to use my
   [personal SSH key](./keys/yubikey.pub))) on the host
3. `nix run github:nix-community/nixos-anywhere -- --flake .#<host-name> --target-host root@<ip address>`

## adding a forgejo actions runner

registration is offline, so nothing has to be minted from the web ui and
nothing has to be copied back out of it. one 40-character hexadecimal secret is
both the runner's identity and its password — forgejo derives the runner's uuid
from the first 16 characters, and the runner host derives the same uuid locally.

runners reach the forge at `git.<tailnet>`, a caddy vhost bound to a userspace
tailscale node on carbon — never at `git.mischief.town`. the runner rewrites
`GITHUB_SERVER_URL` and the artifact endpoints from whatever it connects to, so
cloning and artifact uploads take that path too.

1. add the hostname to `runnerHosts` in
   [secrets/secrets.nix](secrets/secrets.nix), so the secret is encrypted to
   carbon and to that host
2. `openssl rand -hex 20`, then paste it into
   `agenix -e secrets/forgejo/runner-<host>.age`
3. add the hostname to `myNixOS.services.forgejo.runners` on carbon, and set
   `myNixOS.services.forgejo.runner.enable = true` on the host itself
4. rebuild carbon first — it is what creates the runner — then the runner host

removing a runner is not symmetric: dropping it from the config stops carbon
asserting that it exists, but the row stays in the database. delete it from
`/admin/actions/runners`.

registration is closed on the instance, because an open signup form on a forge
with runners is an unauthenticated path to code execution on argon and helium.
accounts are made by hand:

```
forgejo --config /var/lib/forgejo/custom/conf/app.ini admin user create ...
```

## ci

[`.forgejo/workflows/build.yaml`](./.forgejo/workflows/build.yaml) builds every
host on push to `main`, on pull requests, and on demand. The host list is read
out of the flake rather than written in the workflow, so a host added to
[modules/flake/hosts.nix](modules/flake/hosts.nix) is covered by the next run
without a second edit. A `lint` job runs `nixfmt --check`, `deadnix` and
`statix` against the same nixpkgs the flake is locked to.

Jobs run on the `nix` label, a Nix image with git but no node — so no `uses:`
step works there, and the workflow checks out with git by hand. Both runners
mount a Podman named volume at `/nix`, which is what keeps a run from re-fetching
the whole closure from cache.nixos.org: each job leaves a GC root for what it
built, and `nix store gc` at the end of the job removes everything the current
closures no longer need.

Two things follow from that volume:

- it is mounted into *every* job on the runner, writable, because the runner has
  one `container.options` rather than one per label. Fine while this forge has a
  single user; not fine if that changes.
- bumping `myNixOS.services.forgejo.runner.nixImage` starts a fresh volume, since
  the name is derived from the image reference. The old one keeps its disk until
  `podman volume rm` — check with `podman volume ls` as `forgejo-runner`.

Argon and helium have to be rebuilt before any of this runs; the `nix` label is
declared by the runner at startup, and carbon does not create it.

## references

- [aly.codes](https://github.com/alyraffauf/nixcfg)'s nixcfg
- [isabelroses.com](https://github.com/isabelroses/dotfiles)'s configuration
