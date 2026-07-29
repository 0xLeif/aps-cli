#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT

"$repo_root/Scripts/prepare-version.py" --check

while IFS= read -r path; do
    mkdir -p "$temporary_root/$(dirname "$path")"
    cp "$repo_root/$path" "$temporary_root/$path"
done <<'EOF'
VERSION
Sources/aps/Aps.swift
Sources/aps/Schema.swift
Tests/apsTests/APSTests.swift
Scripts/smoke.sh
Scripts/smoke.ps1
plugin.toml
specs/aps-cli/requirements.md
README.md
docs/release-readiness.md
site/app/page.tsx
EOF

perl -pi -e 's/const productVersion = "1\.1\.0"/const productVersion = "9.9.9"/' \
    "$temporary_root/site/app/page.tsx"

if APS_VERSION_ROOT="$temporary_root" "$repo_root/Scripts/prepare-version.py" --check 2>/dev/null; then
    echo "version contract accepted an intentional drift" >&2
    exit 1
fi

echo "version contract positive and negative checks passed"
