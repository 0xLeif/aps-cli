#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
workflow="$repo_root/.github/workflows/release.yml"
formula_workflow="$repo_root/.github/workflows/post-release-formula.yml"
template="$repo_root/Formula/aps.rb.template"
renderer="$repo_root/Scripts/render-homebrew-formula.py"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

sha_a="$(printf a%.0s {1..64})"
sha_b="$(printf b%.0s {1..64})"
sha_c="$(printf c%.0s {1..64})"
formula="$fixture_root/aps.rb"

python3 "$renderer" "$template" "$formula" 1.1.0 "$sha_a" "$sha_b" "$sha_c"

grep -Fq 'version "1.1.0"' "$formula"
grep -Fq 'aps-macos-aarch64' "$formula"
grep -Fq 'aps-macos-x86_64' "$formula"
grep -Fq 'aps-linux-x86_64-portable.tar.gz' "$formula"
grep -Fq 'libexec.install "aps", "lib"' "$formula"
grep -Fq 'bin.write_exec_script libexec/"aps"' "$formula"
test "$(grep -c 'sha256 "' "$formula")" -eq 3

grep -Fq 'Build the final' "$workflow"
grep -Fq 'readelf -d "$package_dir/aps"' "$workflow"
grep -Fq 'docker run --rm' "$workflow"
grep -Fq 'APS_RELEASE_BASE_URL="file://$PWD"' "$workflow"
grep -Fq 'RELEASE_TAG: ${{ needs.provenance.outputs.tag }}' "$workflow"
grep -Fq 'APS_VERSION="${RELEASE_TAG#v}"' "$workflow"
grep -Fq 'test "$RELEASE_TAG" = "v$(cat VERSION)"' "$workflow"
grep -Fq 'test "$("$BIN_DIR/aps" --version)" = "${RELEASE_TAG#v}"' "$workflow"
grep -Fq 'fetch aps-linux-x86_64-portable.tar.gz' "$formula_workflow"
grep -Fq 'Scripts/render-homebrew-formula.py' "$formula_workflow"
grep -Fq 'Homebrew formula updates require a stable SemVer tag' "$formula_workflow"

if python3 "$renderer" "$template" "$formula" 1.1 "$sha_a" "$sha_b" "$sha_c"; then
    echo "invalid formula version was accepted" >&2
    exit 1
fi

echo "release distribution contract checks passed"
