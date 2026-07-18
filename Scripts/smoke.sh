#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ -z "${APS_BIN:-}" ]]; then
  swift build -c debug
  APS_BIN=".build/debug/aps"
fi
bin="$APS_BIN"

"$bin" --help >/dev/null
"$bin" keys | grep -q counter

# `set` prints the value; State is process-local so don't expect get in a new process.
test "$("$bin" set counter 11)" = "11"
test "$("$bin" set message "smoke")" = "smoke"

# StoredState / FileState must survive process boundaries.
"$bin" set flag true >/dev/null
test "$("$bin" get flag)" = "true"

"$bin" set note "smoke-note" >/dev/null
test "$("$bin" get note)" = "smoke-note"

"$bin" dump | grep -q '"key" : "flag"'

"$bin" reset flag >/dev/null
test "$("$bin" get flag)" = "false"

"$bin" reset note >/dev/null
test -z "$("$bin" get note)"

"$bin" reset --all >/dev/null
test "$("$bin" get flag)" = "false"
test -z "$("$bin" get note)"

# Invalid values should fail clearly.
if "$bin" set counter nope >/dev/null 2>&1; then
  echo "expected invalid counter to fail" >&2
  exit 1
fi

echo "smoke ok"
