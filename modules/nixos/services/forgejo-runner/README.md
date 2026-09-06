# Forgejo runner

Carbon runs one persistent runner for trusted repositories. Argon holds
Forgejo, Vaultwarden and the PDS; Helium holds Paperless and the fleet's
backups. The module refuses to share a host with Forgejo or the backup server.

Jobs use rootless Podman as `forgejo-runner`, UID 990. Lingering starts that
user's manager and Podman socket at boot. The runner has no access to the
root-owned Podman socket, and jobs receive neither a container socket nor
permission to mount host paths. There are no host-execution labels.

The `debian` label uses `docker.io/library/node:24-bookworm`, which includes
Node, bash and git for JavaScript actions. The tag is pulled for each job to
pick up image updates. It is not a reproducible image pin. Nix builds need a
separate image or an installation step; no host Nix store is shared.

One job runs at a time, with a one-hour timeout. Each job container defaults to
2 CPUs, 4 GiB of memory and 512 processes. The runner account's user slice caps
all its containers together at 4 CPUs, 6 GiB and 4096 tasks, including service
containers. The runner daemon has a separate 512 MiB limit. These limits leave
room for Carbon's website but do not reserve disk space. Watch Carbon's 100 GB
disk as images and build outputs accumulate.

Containers share Carbon's kernel and can make outbound connections, including
to reachable tailnet services. This configuration does not isolate CI from
the tailnet. Keep the registration scoped to trusted repositories, review
third-party actions, and pin action references to reviewed commits. Public
contribution workflows belong on a dedicated VM with restricted network access.

## registration

This uses the [Forgejo v16 registration flow](https://forgejo.org/docs/latest/admin/actions/registration/).
The pinned runner is 13.1.0; runner and Forgejo version numbers are independent.

1. In `https://code.biscuits.at/user/settings/actions/runners`, create a runner
   named `carbon`. Use a repository's Settings → Actions → Runners instead if
   only that repository should use it. Avoid instance-wide registration.
2. Save the displayed UUID and token on Carbon as
   `/var/lib/forgejo-runner-credentials/connection.json`, owned by `root:root`
   with mode `0600`. The directory must be owned by root with mode `0700`.
   The file contains only these two fields:

   ```json
   { "uuid": "UUID_FROM_FORGEJO", "token": "TOKEN_FROM_FORGEJO" }
   ```

   Use a root editor to enter the values, not a command containing the token
   in shell history. Do not commit this file or put the token in a Nix option.
   `credentialsFile` can also point to a future agenix-managed runtime file;
   encrypted credential creation remains a manual secret operation.
3. Deploy Carbon yourself with `just update carbon`. If you already deployed
   before creating the credential file, run `sudo systemctl start forgejo-runner`
   on Carbon. An absent file deliberately leaves the service stopped.
4. Check `sudo systemctl status forgejo-runner` and
   `sudo journalctl -u forgejo-runner -n 50`. The runner should appear online
   in Forgejo with the `debian` label.

systemd loads the credential file privately and the startup script combines it
with the public settings under `/run/forgejo-runner/config.json`. Neither the
UUID/token file nor that generated configuration enters the Nix store.
Malformed credentials fail startup. After replacing a token, restart
`forgejo-runner` to load it. Revoke the registration in Forgejo when retiring or
replacing the runner. A lost credential can be replaced by creating a new
registration; the container storage is expendable.

Backups exclude `/var/lib/forgejo-runner`, which holds container layers and
workspaces. The sibling credential directory stays in Carbon's encrypted
archives. No database dump paths are excluded by this module.

Enable Actions in a trusted repository and add this smoke workflow as
`.forgejo/workflows/runner-smoke.yaml`:

```yaml
name: runner smoke
on: [push]
jobs:
  smoke:
    runs-on: debian
    steps:
      - run: |
          node --version
          git --version
          test ! -S /var/run/docker.sock
          test ! -e /run/forgejo-runner/config.json
```

This checks dispatch, image startup and the absence of the runner socket and
credentials inside a job. Actions caching is disabled because its proxy needs
a container-reachable listener, which has no allocation in the network policy.

## container maintenance

The rootful `podman-prune` service does not clean this account's storage.
On Carbon, inspect the correct store with:

```bash
sudo -u forgejo-runner env XDG_RUNTIME_DIR=/run/user/990 podman system df
```

For an idle maintenance window, stop the runner, then prune unused containers,
images and networks. Do not run this while jobs are active:

```bash
sudo systemctl stop forgejo-runner
sudo -u forgejo-runner env XDG_RUNTIME_DIR=/run/user/990 podman system prune --all
sudo systemctl start forgejo-runner
```

Restart the runner even if pruning fails. Shutdown waits up to one minute for
the current job, then cancels it. Volumes are not pruned by this command;
inspect `podman volume ls` under the same account before removing any orphaned
volumes manually. The retired runner's shared-Nix-store GC warning in
[the module guide](../../../README.md#retired-runner) still applies if that
design is ever reintroduced.
