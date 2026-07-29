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

candidate_changed=false
if [[ -n "${RELEASE_VERSION+x}" ]]; then
    if [[ "$("$aps_bin" get releaseVersion)" != "$RELEASE_VERSION" ]]; then
        candidate_changed=true
    fi
    "$aps_bin" set releaseVersion "$RELEASE_VERSION" >/dev/null
fi
if [[ -n "${CANDIDATE_COMMIT+x}" ]]; then
    if [[ "$("$aps_bin" get candidateCommit)" != "$CANDIDATE_COMMIT" ]]; then
        candidate_changed=true
    fi
    "$aps_bin" set candidateCommit "$CANDIDATE_COMMIT" >/dev/null
fi
if [[ "$candidate_changed" == true ]]; then
    "$aps_bin" set releasePhase planned >/dev/null
    "$aps_bin" set releaseTestsPassed false >/dev/null
    "$aps_bin" set riskVerdict pending >/dev/null
fi
if [[ -n "${RELEASE_PHASE+x}" ]]; then
    "$aps_bin" set releasePhase "$RELEASE_PHASE" >/dev/null
fi
if [[ -n "${RELEASE_TESTS_PASSED+x}" ]]; then
    "$aps_bin" set releaseTestsPassed "$RELEASE_TESTS_PASSED" >/dev/null
fi
if [[ -n "${RISK_VERDICT+x}" ]]; then
    "$aps_bin" set riskVerdict "$RISK_VERDICT" >/dev/null
fi

"$aps_bin" dump --json
