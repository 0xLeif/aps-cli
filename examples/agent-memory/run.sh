#!/usr/bin/env bash
set -euo pipefail

aps_bin="${APS_BIN:-aps}"
export APS_HOME="${APS_HOME:-$PWD/.aps-agent-example}"

ensure_key() {
    local name="$1"
    shift
    if ! "$aps_bin" keys --quiet | grep -Fxq "$name"; then
        "$aps_bin" key add "$name" "$@" >/dev/null
    fi
}

emit_checkpoint() {
    local keys=(currentIssue workingBranch phase testsPassed blocker)
    local separator=""

    printf '{"checkpoint":['
    for key in "${keys[@]}"; do
        printf '%s' "$separator"
        "$aps_bin" get "$key" --json
        separator=","
    done
    printf ']}\n'
}

ensure_key currentIssue \
    --type Int --storage FileState --path current-issue.json --initial 0 \
    --doc "Issue currently owned by this agent"
ensure_key workingBranch \
    --type String --storage FileState --path working-branch.json --initial "" \
    --doc "Branch currently owned by this agent"
ensure_key phase \
    --type String --storage FileState --path phase.json --initial idle \
    --doc "Current workflow phase"
ensure_key testsPassed \
    --type Bool --storage FileState --path tests-passed.json --initial false \
    --doc "Whether the latest verification passed"
ensure_key blocker \
    --type String --storage FileState --path blocker.json --initial "" \
    --doc "Current blocker, or an empty string"

if [[ -n "${CURRENT_ISSUE+x}" ]]; then
    "$aps_bin" set currentIssue "$CURRENT_ISSUE" >/dev/null
fi
if [[ -n "${WORKING_BRANCH+x}" ]]; then
    "$aps_bin" set workingBranch "$WORKING_BRANCH" >/dev/null
fi
if [[ -n "${WORK_PHASE+x}" ]]; then
    "$aps_bin" set phase "$WORK_PHASE" >/dev/null
fi
if [[ -n "${TESTS_PASSED+x}" ]]; then
    "$aps_bin" set testsPassed "$TESTS_PASSED" >/dev/null
fi
if [[ -n "${BLOCKER+x}" ]]; then
    "$aps_bin" set blocker "$BLOCKER" >/dev/null
fi

emit_checkpoint
