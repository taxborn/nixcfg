# architecture review, completed 2026-09-06

Commit `26a1827` recorded five follow-up tasks from the architecture review.

- [x] Register database requirements with their services. Forgejo and Piper
  derive SQLite dump paths from service settings; Tranquil and Paperless
  register PostgreSQL dumps. Registrations apply when the backup client is
  enabled. Hosts retain repository, retention and source-directory choices.
- [x] Check the build roster, tailnet map and secret rules. Fleet assertions
  check roster agreement, shared recipients, and the existence and recipient
  rules of each configured age file. The restore plan includes all enabled
  backup clients and gives explicit reasons for local tier 2 omissions.
- [x] Move machine-specific disk layouts and serials into `hosts/<host>/disko.nix`.
  The flake exports reusable layouts. The MX Master 3S configuration lives in
  a hardware module selected by the workstation profile.
- [x] Type the network registry. Entries require a domain and port, reject
  unknown fields, and require SSH hostname and port together. Ports range from
  1 through 65535; zero would let the service choose a port Caddy cannot know.
- [x] Consolidate documentation. The module guide owns module conventions and
  fleet checks, CONTEXT owns vocabulary and network policy, AGENTS owns agent
  permissions and validation, and the secret and backup guides own operations.
  The earlier maintenance table now lives in its own dated review.

## validation

`just check` and `nix flake check` passed. Full system builds passed for Argon,
Carbon, Helium, Tungsten and Uranium, including Tungsten's NVIDIA specialisation.
Local documentation links and heading anchors were checked after consolidation.

Regression checks cover database path changes, a disabled backup client,
missing tailnet entries, wrong secret recipients and malformed network entries.
The restore runner uses mocked commands to check full coverage, continued work
after a canary failure, and failure before decryption when plan evaluation fails.

Evaluated filesystem, LUKS, GRUB, mouse and borgmatic settings matched the
pre-refactor baseline on all five hosts. Actual restore rehearsals remain
interactive operations described in the [backup guide](../../modules/nixos/services/backups/README.md#testing-restore).
Recipient checks read public rules and do not prove encrypted files were rekeyed.
