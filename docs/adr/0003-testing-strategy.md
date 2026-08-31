# Testing is pure-eval checks and real restore drills; VM tests are deferred

There are no `nixosTest`s in this repo, and that is deliberate. Coverage comes
from three places instead: CI building all five host closures, pure-eval
`checks` asserting invariants a build cannot (roster consistency, the
`smartd`/`physicalDisks` agreement), and the restore ladder in the justfile —
`just restore-all`, which exercises the real borg repositories over the real
network with the real yubikey.

That last one is why per-host VM smoke tests were rejected rather than deferred.
A VM test asserting "the units reach active" duplicates two things that already
exist: CI proves the closure builds, and the `systemd` collector on the
monitoring client asserts unit health against the actual running hosts,
continuously. It would look like coverage and add none.

**Per-service integration tests are deferred, not rejected.** The things worth
testing are the mechanisms this repo invents, which have no upstream test behind
them: the borg forced-command restriction that confines each client to its own
repository path, the token-to-UUID derivation shared between `actions.nix` and
`runner.nix`, and Caddy vhost routing. Build them when a service module gains a
**second consumer** — that is the point at which a change stops being verifiable
by rebuilding the one host that uses it.

## Consequences

A caveat that must survive into whatever gets built: **a `nixosTest` node cannot
reproduce the boot layer.** Disko's LUKS RAID1 on Tungsten and Uranium,
lanzaboote's secure-boot chain, and the FIDO2 unlock do not exist in a VM. A
per-host VM test would assert the service layer while silently asserting nothing
about the layer most likely to lock a machine out of its own root filesystem.
For interactive local checks of a host, `nixos-rebuild build-vm --flake .#<host>`
already exists and needs no framework; the deferred work is automated asserting
tests, which is a different and much smaller thing.
