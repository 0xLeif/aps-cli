#!/usr/bin/env bash
set -euo pipefail

action_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
action_file="$action_dir/action.yml"
installer="$action_dir/install.sh"
repo_root="$(cd -- "$action_dir/../../.." && pwd)"

grep -Fq 'using: composite' "$action_file"
grep -Fq 'default: "${{ github.action_ref }}"' "$action_file"
grep -Fq 'runner.os != '\''Windows'\''' "$action_file"
grep -Fq 'runner.os == '\''Windows'\''' "$action_file"
grep -Fq 'curl --fail --location --retry 5' "$installer"
grep -Fq 'semver_pattern=' "$installer"
grep -Fq '1.0.0-rc.1' "$installer"
grep -Fq 'sha256sum' "$installer"
grep -Fq 'shasum -a 256' "$installer"
grep -Fq 'echo "$install_dir" >> "$GITHUB_PATH"' "$installer"
grep -Fq 'echo "APS_HOME=$aps_home" >> "$GITHUB_ENV"' "$installer"
grep -Fq 'Linux:X64) asset="aps-linux-x86_64-portable.tar.gz"' "$installer"
grep -Fq 'tar -xzf' "$installer"
grep -Fq 'Portable aps archive is missing' "$installer"
grep -Fq 'macOS:X64' "$installer"
grep -Fq 'macOS:ARM64' "$installer"
grep -Fq 'No aps release binary is published' "$installer"
grep -Fq 'install-action-test' "$repo_root/fledge.toml"
grep -Fq 'aps-linux-x86_64-portable.tar.gz' "$repo_root/.github/workflows/release.yml"
grep -Fq -- '-Xlinker -rpath -Xlinker "\$ORIGIN/lib"' "$repo_root/.github/workflows/release.yml"

for version in 1.0.0 1.0.0-rc.1 1.0.0+build.1 1.0.0-rc.1+build.1; do
    APS_VERSION="$version" APS_VALIDATE_VERSION_ONLY=1 "$installer"
done
if APS_VERSION=1.0 APS_VALIDATE_VERSION_ONLY=1 "$installer"; then
    echo "invalid SemVer was accepted" >&2
    exit 1
fi

echo "install-aps Action contract checks passed"
