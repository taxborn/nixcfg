# Single host roster

Status: ready-for-human

## Problem

Adding a host means editing five parallel lists:

| Place                                     | What it holds                          |
| ----------------------------------------- | -------------------------------------- |
| `modules/flake/hosts.nix`                 | the `genAttrs` name list                |
| `modules/snippets/tailscale.nix`          | `tailscaleIPs`, `alwaysOn`, `physicalDisks` |
| `modules/snippets/sshKnownHosts.nix`      | hostnames and public key file           |
| `secrets/secrets.nix`                     | the `hosts` list driving borg rules     |
| `keys/root_<host>.pub`                    | the key itself                          |

`tailscale.nix` already calls its map "the fleet roster" in its own description,
which is the tell: the concept exists, it just has five encodings.

Every omission is silent. A host missing from `tailscaleIPs` is not monitored
and not backed up, and nothing fails — it simply is not there. A host missing
from `secrets.nix` gets a failed decrypt at activation for every secret its
modules ask for, which is at least loud, but only on that host and only at
deploy time.

At five hosts this is annoying. At eight it is a defect.

## The constraint that picks the design

`secrets/secrets.nix` is read by the **agenix CLI**, as a plain Nix file,
outside any flake evaluation. It cannot reach a flake output. So the roster has
to be a plain `.nix` file that `import` can reach from anywhere.

This is the whole reason the roster is not simply an attribute in `flake.nix`.
Recorded as ADR-0001, because it is invisible in the code and the obvious
"improvement" is to move it into the flake, which breaks secrets.

## Shape

`hosts/roster.nix` — a plain attrset, one entry per host.

**What goes in**: facts *other* hosts read.

- `tailscaleIP` — the monitoring server derives scrape targets, backup clients
  address Helium, `sshKnownHosts` keys its entries
- `alwaysOn` — decides `node` vs `node-intermittent` and whether the down alert
  covers this host
- `physicalDisks` — decides whether the client runs `smartctl_exporter` and
  whether the server scrapes it
- `publicIP` — Argon and Carbon only; `sshKnownHosts` needs it
- `borgRole` — `server` for Helium, `client` elsewhere; lets Helium's
  `authorizedKeys` derive itself instead of naming four hosts by hand

**What stays out**: the host's class. `profiles.server.enable` is read by nobody
but that host, and moving it splits a host's definition across two files for no
gain. The line is: *the roster holds facts other hosts need; `hosts/<host>/`
holds facts only that host needs.*

## Consumers

`mySnippets.tailnet` **survives**. It stays the module-facing interface and its
`default =` is derived from the roster. That is what keeps this a change to one
file rather than to every consumer — monitoring, backups and the ssh modules do
not change at all, and the definition of "snippet" in `CONTEXT.md` stays true.

- `modules/flake/hosts.nix` — `mapAttrs` over the roster instead of `genAttrs`
  over a literal list
- `modules/snippets/tailscale.nix` — three defaults derived from it
- `modules/snippets/sshKnownHosts.nix` — entries generated per host, with the
  bracketed `[ip]:port` forms preserved exactly (they are load-bearing; see the
  comments there)
- `secrets/secrets.nix` — `import ../hosts/roster.nix` for its `hosts` list
- `modules/nixos/services/backups` — Helium's `authorizedKeys` from `borgRole`

## Keep the prose

The descriptions on `alwaysOn` and `physicalDisks` are the best documentation in
this repo — they explain *why* a laptop is not alerted on and why a VPS answers
no SMART command. Moving to per-host attributes must not scatter them. They
belong on the roster's submodule option descriptions, where they are still one
paragraph in one place.

## Add a check

A pure-eval `checks` entry asserting roster consistency: every host has a
`keys/root_<host>.pub`, an IP, and reachable borg secret paths. This is the
class of failure a build cannot catch, and it is cheap.

## Done when

Adding a host is one entry in `hosts/roster.nix` plus its key file, and a host
that is half-added fails evaluation rather than going quietly unmonitored.
