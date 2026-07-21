#!/usr/bin/env bash
# Portable `swift test` wrapper: Linux needs --allow-shlib-undefined for the
# Observation toolchain bug on 6.0.x (same as CI Linux cells).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ "$(uname -s)" == "Linux" ]]; then
  swift test -Xlinker --allow-shlib-undefined "$@"
else
  swift test "$@"
fi
