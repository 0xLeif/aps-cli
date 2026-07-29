#!/usr/bin/env bash
set -euo pipefail

real_aps_bin="${REAL_APS_BIN:?Set REAL_APS_BIN to the aps executable}"

if [[ "${1:-}" == "keys" && "${2:-}" == "--quiet" ]]; then
    "$real_aps_bin" "$@"
    for ((index = 0; index < 12000; index += 1)); do
        printf 'paddingKey%05d\n' "$index"
    done
else
    exec "$real_aps_bin" "$@"
fi
