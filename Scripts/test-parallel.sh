#!/usr/bin/env bash
# Run the unit suite under SwiftPM parallel workers.
# Proves APSTests isolation (per-case FileState path, hermetic UserDefaults,
# Application resets, DynamicKeyStorage memory clear, and the setUp/tearDown
# gate) prevents cross-talk when workers interleave cases.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

workers="${APS_TEST_WORKERS:-4}"

echo "test-parallel: swift test --parallel --num-workers ${workers}"
if [[ "$(uname -s)" == "Linux" ]]; then
  # libswiftObservation.so has an undefined swift::threading::fatal ref on
  # Linux 6.0.x toolchains; same allowance as linux-smoke / CI Linux cells.
  swift test --parallel --num-workers "${workers}" -Xlinker --allow-shlib-undefined
else
  swift test --parallel --num-workers "${workers}"
fi
