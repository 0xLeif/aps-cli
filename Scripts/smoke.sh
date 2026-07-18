#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

SMOKE_HOME="${APS_HOME:-$(mktemp -d "${TMPDIR:-/tmp}/aps-smoke.XXXXXX")}"
export APS_HOME="$SMOKE_HOME"
mkdir -p "$APS_HOME"

if [[ -z "${APS_BIN:-}" ]]; then
  swift build -c debug
  APS_BIN=".build/debug/aps"
fi
bin="$APS_BIN"

"$bin" --help >/dev/null
test "$("$bin" --version)" = "0.2.0"
"$bin" keys | grep -q counter
"$bin" keys | grep -q profile
"$bin" keys --json | grep -q '"key" : "profile"'

# `set` prints the value; State is process-local so don't expect get in a new process.
test "$("$bin" set counter 11)" = "11"
test "$("$bin" set message "smoke")" = "smoke"
"$bin" set counter 11 --json | grep -q '"value" : 11'

# StoredState / FileState must survive process boundaries.
"$bin" set flag true >/dev/null
test "$("$bin" get flag)" = "true"
"$bin" get flag --json | grep -q '"value" : true'

"$bin" set note "smoke-note" >/dev/null
test "$("$bin" get note)" = "smoke-note"

"$bin" set profile '{"name":"smoke","version":2}' >/dev/null
"$bin" get profile --json | grep -q '"name" : "smoke"'
"$bin" get profile --json | grep -q '"version" : 2'

# --state-dir overrides APS_HOME
OTHER="$(mktemp -d "${TMPDIR:-/tmp}/aps-smoke-other.XXXXXX")"
"$bin" set note "other-root" --state-dir "$OTHER" >/dev/null
test "$("$bin" get note --state-dir "$OTHER")" = "other-root"
test "$("$bin" get note)" = "smoke-note"

"$bin" dump | grep -q '"key" : "flag"'
"$bin" dump --json | grep -q '"key" : "profile"'

"$bin" reset flag >/dev/null
test "$("$bin" get flag)" = "false"

"$bin" reset note >/dev/null
test -z "$("$bin" get note)"

"$bin" reset profile --json | grep -q '"reset" : "key"'

"$bin" reset --all >/dev/null
test "$("$bin" get flag)" = "false"
test -z "$("$bin" get note)"

# Bounded watch should exit.
"$bin" watch counter --count 1 --timeout 2 >/dev/null

# ObservedDependency stats command (process-local; fresh process starts at 0).
"$bin" stats --json | grep -q '"mutationCount" : 0'
"$bin" stats --watch --count 1 --timeout 2 >/dev/null

# Invalid values should fail clearly.
if "$bin" set counter nope >/dev/null 2>&1; then
  echo "expected invalid counter to fail" >&2
  exit 1
fi

echo "smoke ok"
