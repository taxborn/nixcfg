#!/usr/bin/env bash
set -euo pipefail

shell_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$shell_dir/../.." && pwd)
# Both workstations use the same nixpkgs and architecture. Resolve dependencies
# from the fleet lock, rather than fetching an unrelated Qt from a registry.
exec nix shell \
    "$repo_dir#nixosConfigurations.uranium.pkgs.quickshell" \
    "$repo_dir#nixosConfigurations.uranium.pkgs.python3" \
    --command bash "$shell_dir/session.sh" "$@"
