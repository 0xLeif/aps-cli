#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
vendor_dir="$repo_root/site/vendor/0x"
expected_revision="26fb2108a0e4c8ba65c06f1d70983e7dce298112"

test "$(cat "$vendor_dir/REVISION")" = "$expected_revision"
(
    cd "$vendor_dir"
    shasum -a 256 --check SHA256SUMS
)
grep -Fq 'GENERATED FILE' "$vendor_dir/tokens.css"
grep -Fq '.h-btn' "$vendor_dir/components.css"
grep -Fq 'const STORE_KEY = "0x-theme"' "$vendor_dir/theme.js"
grep -Fq 'MIT License' "$vendor_dir/LICENSE"
grep -Fq 'tofu-ux/0x' "$repo_root/README.md"
grep -Fq '0xLeif/0x' "$repo_root/README.md"
grep -Fq 'source_repo="0xLeif/0x"' "$repo_root/Scripts/sync-0x.sh"

echo "0x vendor contract checks passed"
