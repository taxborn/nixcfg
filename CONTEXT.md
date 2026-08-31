# nixcfg

The NixOS configuration for every machine Braxton runs — two OVH VPS, a home
server, a laptop and a desktop — plus the services they host under
`mischief.town` and the tailnet that joins them.

## Language

**Fleet**:
Every machine this repo configures, taken together. Growth is servers; the
workstation set is closed.

**Host**:
One machine with a `nixosConfiguration` here, named after an element.
_Avoid_: Node, machine, box, server (a server is one *kind* of host)

**Roster**:
The one record of which hosts exist and the facts other hosts need about them —
tailnet address, whether absence is a fault, whether it has disks worth asking
about SMART. A fact only one host reads is not roster material; it belongs to
that host.
_Avoid_: Inventory, host list, registry

**Profile**:
A host class. A host has exactly one, and it decides what that machine is for.
There are two: server and workstation.
_Avoid_: Using this for a single-concern module — that is a Feature

**Feature**:
One concern a host can switch on, enabled by a Profile rather than chosen
per host. Audio, bluetooth, swap, containers.
_Avoid_: Profile

**Snippet**:
A module under `modules/snippets/` that declares shared fleet data as options
and sets no config. The network map, the SSH port and the known-hosts table are
snippets: facts both NixOS and Home Manager modules read, held in one place so
two consumers cannot disagree about them.
_Avoid_: Constants, registry, config, settings

**Tailnet**:
The Tailscale network every host joins, and the only network on which the fleet
addresses itself. Reaching a host by any other path is the exception, and each
one is documented where it happens.
