#!/usr/bin/env bash
# Prove aps is usable as a CI helper: job-scoped state root, dynamic FileState
# keys, cross-process get/set, and JSON dump. Demo seed keys are left alone.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ -z "${APS_BIN:-}" ]]; then
  ./Scripts/build.sh -c debug
  APS_BIN=".build/debug/aps"
fi
bin="$APS_BIN"

DOGFOOD_HOME="$(mktemp -d "${TMPDIR:-/tmp}/aps-ci-dogfood.XXXXXX")"
export APS_HOME="$DOGFOOD_HOME"
cleanup() { rm -rf "$DOGFOOD_HOME"; }
trap cleanup EXIT

"$bin" schema >/dev/null

"$bin" key add ciStatus --type String --storage FileState --path ci-status.json --initial '' --doc 'CI lane status'
"$bin" key add ciRun --type String --storage FileState --path ci-run.json --initial '' --doc 'CI run id or branch'

"$bin" set ciStatus starting >/dev/null
"$bin" set ciRun "${GITHUB_RUN_ID:-local}-$(uname -s)" >/dev/null

# Fresh process: FileState must survive (State would not).
test "$("$bin" get ciStatus)" = "starting"
"$bin" set ciStatus ok >/dev/null
test "$("$bin" get ciStatus)" = "ok"

"$bin" get ciStatus --json | grep -q '"value":"ok"'
"$bin" dump --json | grep -q '"key":"ciStatus"'
"$bin" dump --json | grep -q '"key":"ciRun"'

# Demo keys remain available and untouched by the helper keys.
"$bin" keys | grep -q counter
"$bin" keys | grep -q ciStatus

echo "ci-dogfood ok (APS_HOME=$APS_HOME)"
