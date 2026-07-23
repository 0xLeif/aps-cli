#!/usr/bin/env bash
set -euo pipefail

action_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
action_file="$action_dir/action.yml"
installer="$action_dir/install.sh"

grep -Fq 'using: composite' "$action_file"
grep -Fq 'default: "${{ github.action_ref }}"' "$action_file"
grep -Fq 'runner.os != '\''Windows'\''' "$action_file"
grep -Fq 'runner.os == '\''Windows'\''' "$action_file"
grep -Fq 'curl --fail --location --retry 5' "$installer"
grep -Fq 'sha256sum' "$installer"
grep -Fq 'shasum -a 256' "$installer"
grep -Fq 'echo "$install_dir" >> "$GITHUB_PATH"' "$installer"
grep -Fq 'echo "APS_HOME=$aps_home" >> "$GITHUB_ENV"' "$installer"
grep -Fq 'Linux:X64' "$installer"
grep -Fq 'macOS:X64' "$installer"
grep -Fq 'macOS:ARM64' "$installer"
grep -Fq 'No aps release binary is published' "$installer"

echo "install-aps Action contract checks passed"
