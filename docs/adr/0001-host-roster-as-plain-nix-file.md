# The host roster is a plain Nix file, not a flake output

The fleet roster — which hosts exist, their tailnet addresses, whether their
absence is a fault, whether they have disks worth asking about SMART — lives at
`hosts/roster.nix` as a plain attrset that anything can `import`. The obvious
alternative, and the one a reader will reach for, is to make it an attribute in
`flake.nix` or a `flake.` output beside `nixosConfigurations`.

That does not work, for a reason invisible from the roster itself:
**`secrets/secrets.nix` is read by the agenix CLI, not by Nix evaluating this
flake.** agenix loads it as a standalone file to decide which public keys may
decrypt each `.age` path. It has no flake, no `self`, and no way to reach a
flake output. A roster the secrets rules cannot see is a roster that still
leaves the host list duplicated in the one place where getting it wrong means a
host cannot decrypt its own borg passphrase.

So the file is plain, and every consumer imports it: `modules/flake/hosts.nix`,
`modules/snippets/tailscale.nix`, `modules/snippets/sshKnownHosts.nix`,
`secrets/secrets.nix`, and the backups module.

## Consequences

`mySnippets.tailnet` stays, with its defaults derived from the roster rather
than written out. It remains the interface modules read; the roster is only the
data behind it. That keeps `CONTEXT.md`'s definition of a snippet true and means
monitoring and backups did not have to change when the roster arrived.

The roster holds only facts that *other* hosts read. A host's class
(`profiles.server.enable`) is read by nobody but that host and stays in
`hosts/<host>/default.nix` — splitting a host's own definition across two files
buys nothing.
