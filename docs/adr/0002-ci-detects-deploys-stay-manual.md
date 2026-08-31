# CI detects regressions; it does not gate, and deploys stay manual

Forgejo Actions builds all five host closures on every push to `main`, and that
is all it does. There is no branch protection, no PR requirement, and
`just update <host>` does not consult a commit status before deploying.

This looks like a missing gate and is not. `nixos-rebuild --target-host` builds
locally before it switches, so a configuration that does not build never reaches
the host it was aimed at — that protection already exists and CI cannot improve
on it. The failure CI actually catches is the other one: a change to a shared
module like `modules/nixos/base.nix` is deployed to Carbon, and Tungsten
silently stops evaluating until the next time that laptop is rebuilt, which
could be weeks. CI is a fleet-wide regression detector. Gating adds ceremony to
a single-user forge whose pushes are already tailnet-only, and gates nothing
that is not already covered.

Deploys stay manual for a related reason, and two alternatives were rejected:

**deploy-rs** buys parallel deploys and magic rollback — a host that cannot
confirm reachability after activation reverts itself, which is exactly the
"config built fine and killed networking on an OVH box" scenario. Real
protection, and worth revisiting **when a third VPS lands**. At five hosts, with
a rescue console available, it is an extra input, a second deploy path, and a
second way to describe the fleet.

**`system.autoUpgrade`** is rejected outright rather than deferred. Every host
tracks `nixos-unstable`. Unattended upgrades on unstable, with nothing gating
them, is the mechanism that turns one bad lock bump into five bad hosts
overnight. A release channel for servers was considered as the way to make it
safe and rejected too: it doubles the nixpkgs surface to solve a problem the CI
build already solves, since a lock bump that breaks a host now shows up as a red
run.

## Consequences

CI failures arrive by email rather than ntfy, where every other fleet alert
goes. The ntfy topic is encrypted to Argon's host key and a job container cannot
read an agenix secret, so routing there needs a Forgejo Actions secret holding a
second copy of the topic — a new place for it to leak from, to save one
notification hop.

Knowing which hosts are actually current becomes the job of a metric rather than
of the deploy tool: `nixcfg_deploy_timestamp_seconds`, alerting at 14 days on
always-on hosts.
