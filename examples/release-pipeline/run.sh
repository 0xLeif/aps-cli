#!/usr/bin/env bash
set -euo pipefail

aps_bin="${APS_BIN:-aps}"
export APS_HOME="${APS_HOME:-$PWD/.aps-release-example}"

ensure_key() {
    local name="$1"
    shift
    if ! "$aps_bin" keys --quiet | grep -Fxq "$name"; then
        "$aps_bin" key add "$name" "$@"
    fi
}

ensure_key releaseVersion \
    --type String --storage FileState --path release-version.json --initial "" \
    --doc "Release version under evaluation"
ensure_key candidateCommit \
    --type String --storage FileState --path candidate-commit.json --initial "" \
    --doc "Exact release candidate commit"
ensure_key releasePhase \
    --type String --storage FileState --path release-phase.json --initial planned \
    --doc "Current release phase"
ensure_key releaseTestsPassed \
    --type Bool --storage FileState --path release-tests-passed.json --initial false \
    --doc "Whether release verification passed"
ensure_key riskVerdict \
    --type String --storage FileState --path risk-verdict.json --initial pending \
    --doc "Latest deterministic risk verdict"

"$aps_bin" set releaseVersion "${RELEASE_VERSION:-1.1.0}" >/dev/null
"$aps_bin" set candidateCommit "${CANDIDATE_COMMIT:-local}" >/dev/null
"$aps_bin" set releasePhase "${RELEASE_PHASE:-verifying}" >/dev/null
"$aps_bin" set releaseTestsPassed "${RELEASE_TESTS_PASSED:-true}" >/dev/null
"$aps_bin" set riskVerdict "${RISK_VERDICT:-proceed}" >/dev/null

"$aps_bin" dump --json
