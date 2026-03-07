# nixpkgs binary cache miss — slow builds after flake update

## symptoms

after `nix flake update`, a rebuild triggers a long local compilation of a
package that should be available as a binary substitute.

## root cause

nixpkgs was bumped to a revision where the package version changed and the
corresponding Hydra build hasn't passed yet (or failed). `cache.nixos.org`
only serves binaries for successfully completed Hydra jobs, so nix falls back
to building from source.

## diagnosis

**check if the binary is in cache.nixos.org:**
```bash
nix path-info --store https://cache.nixos.org 'nixpkgs#<package-attr>'
# e.g. nixpkgs#rocmPackages.hipblaslt
# 404 / error = not cached for this nixpkgs rev
```

**check Hydra build status:**
```
https://hydra.nixos.org/job/nixpkgs/trunk/<package-attr>.x86_64-linux
# e.g. https://hydra.nixos.org/job/nixpkgs/trunk/rocmPackages.hipblaslt.x86_64-linux
```

Find the last green build, and click the build number. Then, you can find a derivation that it was built with; though if it states, for example, evaluation 1823157 (and 22 others), click the "22 others" link and get the commit labeled at the "Input changes" column.

**check what version is currently in the local store:**
```bash
nix path-info -r /run/current-system | grep <package-name>
# e.g. grep hipblaslt
```

## resolution

find the last nixpkgs commit where Hydra had a passing build for the package,
then pin to it:

```bash
nix flake lock --update-input nixpkgs --override-input nixpkgs github:NixOS/nixpkgs/<commit-sha>
```

commit the updated `flake.lock`.

## when to unpin

monitor the Hydra job until a newer build passes, then:

```bash
nix flake update
```

## notes

- ROCm/CUDA packages are frequent offenders due to long build times and
  complex dependency graphs
- Hydra build history shows the last passing commit in the build list
- Happened for Zed at one point as well
