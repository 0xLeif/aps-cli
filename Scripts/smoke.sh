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
"$bin" keys | grep -q secret
"$bin" keys --json | grep -q '"key":"profile"'
"$bin" keys --json | grep -q '"key":"secret"'

# `set` prints the value; State is process-local so don't expect get in a new process.
test "$("$bin" set counter 11)" = "11"
test "$("$bin" set message "smoke")" = "smoke"
"$bin" set counter 11 --json | grep -q '"value":11'

# StoredState / FileState must survive process boundaries.
"$bin" set flag true >/dev/null
test "$("$bin" get flag)" = "true"
"$bin" get flag --json | grep -q '"value":true'

"$bin" set note "smoke-note" >/dev/null
test "$("$bin" get note)" = "smoke-note"

"$bin" set profile '{"name":"smoke","version":2}' >/dev/null
"$bin" get profile --json | grep -q '"name":"smoke"'
"$bin" get profile --json | grep -q '"version":2'

# Encrypted-file secret store: key-file mode round-trip, perms, reset.
# Clear passphrase env so key-file mode is exercised (agents may inherit it).
unset APS_SECRET_PASSPHRASE APS_SECRET_USE_PASSPHRASE || true
"$bin" set secret "smoke-secret" >/dev/null
test "$("$bin" get secret)" = "smoke-secret"
"$bin" get secret --json | grep -q '"storage":"EncryptedFile"'
if [[ "$(uname -s)" == "Darwin" ]]; then
  test "$(stat -f "%Lp" "$APS_HOME/secret.key")" = "600"
else
  test "$(stat -c "%a" "$APS_HOME/secret.key")" = "600"
fi
"$bin" reset secret >/dev/null
test -z "$("$bin" get secret)"
test ! -f "$APS_HOME/secret.enc"

# Passphrase mode: right phrase works, wrong phrase fails with a loud error.
APS_SECRET_PASSPHRASE=smoke-pass "$bin" set secret "phrase-secret" >/dev/null
test "$(APS_SECRET_PASSPHRASE=smoke-pass "$bin" get secret)" = "phrase-secret"
if APS_SECRET_PASSPHRASE=wrong-pass "$bin" get secret >/dev/null 2>&1; then
  echo "expected wrong passphrase to fail" >&2
  exit 1
fi
"$bin" reset secret >/dev/null

# --state-dir overrides APS_HOME
OTHER="$(mktemp -d "${TMPDIR:-/tmp}/aps-smoke-other.XXXXXX")"
"$bin" set note "other-root" --state-dir "$OTHER" >/dev/null
test "$("$bin" get note --state-dir "$OTHER")" = "other-root"
test "$("$bin" get note)" = "smoke-note"

"$bin" dump | grep -q '"key":"flag"'
"$bin" dump --json | grep -q '"key":"profile"'
"$bin" dump --json | grep -q '"key":"secret"'

"$bin" reset flag >/dev/null
test "$("$bin" get flag)" = "false"

"$bin" reset note >/dev/null
test -z "$("$bin" get note)"

"$bin" reset profile --json | grep -q '"reset":"key"'

"$bin" reset --all >/dev/null
test "$("$bin" get flag)" = "false"
test -z "$("$bin" get note)"

# Bounded watch should exit.
"$bin" watch counter --count 1 --timeout 2 >/dev/null

# ObservedDependency stats command (process-local; fresh process starts at 0).
"$bin" stats --json | grep -q '"mutationCount":0'
"$bin" stats --watch --count 1 --timeout 2 >/dev/null

# Invalid values should fail clearly.
if "$bin" set counter nope >/dev/null 2>&1; then
  echo "expected invalid counter to fail" >&2
  exit 1
fi

# Error contract: taxonomy exit codes, stdout purity, JSON envelope.
out="$("$bin" set counter nope 2>/dev/null)" && { echo "expected invalid counter to fail" >&2; exit 1; }
test $? -eq 64 || { echo "expected exit 64 for invalid value" >&2; exit 1; }
test -z "$out" || { echo "stdout must stay empty on error" >&2; exit 1; }
err="$("$bin" set counter nope --json 2>&1 >/dev/null || true)"
echo "$err" | grep -q '"code":"invalid_value"'

# Corrupt persisted state exits 65 with a corrupt_state envelope.
echo 'garbage{{' > "$APS_HOME/note.json"
out="$("$bin" get note 2>/dev/null)" && { echo "expected corrupt note to fail" >&2; exit 1; }
test $? -eq 65 || { echo "expected exit 65 for corrupt state" >&2; exit 1; }
test -z "$out" || { echo "stdout must stay empty on corrupt state" >&2; exit 1; }
err="$("$bin" get note --json 2>&1 >/dev/null || true)"
echo "$err" | grep -q '"code":"corrupt_state"'
"$bin" reset note >/dev/null

# Unwritable state root exits 73 on write.
BADROOT="$(mktemp "${TMPDIR:-/tmp}/aps-smoke-file.XXXXXX")"
out="$("$bin" set note x --state-dir "$BADROOT" 2>/dev/null)" && { echo "expected unwritable root to fail" >&2; exit 1; }
test $? -eq 73 || { echo "expected exit 73 for unwritable state root" >&2; exit 1; }
rm -f "$BADROOT"

# APS_ERROR_JSON=1 opts into structured errors without --json.
err="$(APS_ERROR_JSON=1 "$bin" set flag maybe 2>&1 >/dev/null || true)"
echo "$err" | grep -q '"code":"invalid_value"'

# TTY contract: piped output stays plain (TSV, no ANSI), --quiet prints names only.
"$bin" keys | grep -q $'KEY\tTYPE'
if "$bin" keys | grep -q $'\x1b'; then
  echo "piped keys output must not contain ANSI escapes" >&2
  exit 1
fi
test "$("$bin" keys --quiet | head -1)" = "counter"
test "$("$bin" keys --quiet | wc -l | tr -d ' ')" = "7"

# JSON is compact when piped (gh rule); --json accepted as --jsonl alias on watch.
"$bin" dump | grep -q '"key":"flag"'
"$bin" watch counter --count 1 --timeout 2 --json >/dev/null

# Watch termination semantics: exit codes and stream markers.
"$bin" watch counter --count 1 --jsonl >/dev/null
"$bin" watch counter --count 1 --jsonl | grep -q '"reason":"count"'
out="$("$bin" watch counter --timeout 1 --jsonl >/dev/null 2>&1)" && { echo "expected timeout exit" >&2; exit 1; }
test $? -eq 124 || { echo "expected exit 124 for timeout" >&2; exit 1; }
out="$("$bin" watch counter --timeout 1 --jsonl 2>/dev/null || true)"
echo "$out" | grep -q '"reason":"timeout"'
"$bin" watch counter --jsonl > "$APS_HOME/watch.out" 2>/dev/null &
WPID=$!
sleep 1
kill -INT $WPID
# Bounded wait: the signal must stop the watch within a few seconds.
RC=0
for _ in $(seq 1 20); do
  kill -0 $WPID 2>/dev/null || break
  sleep 0.5
done
if kill -0 $WPID 2>/dev/null; then
  echo "watch did not stop on signal" >&2
  kill -KILL $WPID 2>/dev/null || true
  exit 1
fi
wait $WPID || RC=$?
test "${RC:-0}" -eq 130 || { echo "expected exit 130 for SIGINT, got ${RC:-0}" >&2; exit 1; }
grep -q '"reason":"sigint"' "$APS_HOME/watch.out"
if grep -vq '^{' "$APS_HOME/watch.out"; then
  echo "jsonl stream must contain only JSON lines" >&2
  exit 1
fi

echo "smoke ok"
