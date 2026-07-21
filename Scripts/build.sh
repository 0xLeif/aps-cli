#!/usr/bin/env bash
# Portable `swift build` wrapper: Linux needs --allow-shlib-undefined for the
# Observation toolchain bug on 6.0.x (same as CI Linux cells).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ "$(uname -s)" == "Linux" ]]; then
  swift build -Xlinker --allow-shlib-undefined "$@"
else
  swift build "$@"
fi
