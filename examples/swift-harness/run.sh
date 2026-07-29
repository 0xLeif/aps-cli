#!/usr/bin/env bash
set -euo pipefail

example_dir="$(cd "$(dirname "$0")" && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/aps-swift-harness.XXXXXX")"
cleanup() {
    if [[ -n "$build_dir" && -d "$build_dir" ]]; then
        rm -rf "$build_dir"
    fi
}
trap cleanup EXIT

export APS_BIN="${APS_BIN:-aps}"
export APS_HOME="${APS_HOME:-$PWD/.aps-swift-harness-example}"

swiftc -parse-as-library \
    "$example_dir/StateHarness.swift" \
    -o "$build_dir/state-harness"
"$build_dir/state-harness"
