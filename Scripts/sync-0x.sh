#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
revision="26fb2108a0e4c8ba65c06f1d70983e7dce298112"
vendor_dir="$repo_root/site/vendor/0x"
source_repo="0xLeif/0x"
temporary_dir="$(mktemp -d "$repo_root/site/vendor/.0x-sync.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

staged_dir="$temporary_dir/staged"
mkdir -p "$staged_dir"

fetch() {
    local source="$1"
    local destination="$2"
    gh api \
        -H "Accept: application/vnd.github.raw+json" \
        "repos/${source_repo}/contents/${source}?ref=${revision}" \
        > "$staged_dir/$destination"
    test -s "$staged_dir/$destination"
}

fetch assets/tokens.css tokens.css
fetch assets/components.css components.css
fetch assets/theme.js theme.js
fetch LICENSE LICENSE

printf '%s\n' "$revision" > "$staged_dir/REVISION"
(
    cd "$staged_dir"
    shasum -a 256 tokens.css components.css theme.js LICENSE \
        > SHA256SUMS
    shasum -a 256 -c SHA256SUMS
)

if [ -d "$vendor_dir" ]; then
    mv "$vendor_dir" "$temporary_dir/previous"
fi
if ! mv "$staged_dir" "$vendor_dir"; then
    if [ -d "$temporary_dir/previous" ]; then
        mv "$temporary_dir/previous" "$vendor_dir"
    fi
    exit 1
fi

echo "synced $source_repo at $revision (upstream: tofu-ux/0x)"
