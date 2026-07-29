#!/usr/bin/env bash
set -euo pipefail

aps_bin="${APS_BIN:-aps}"
export APS_HOME="${APS_HOME:-$PWD/.aps-agent-example}"

ensure_key() {
    local name="$1"
    shift
    if ! "$aps_bin" keys --quiet | grep -Fxq "$name"; then
        "$aps_bin" key add "$name" "$@"
    fi
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

"$aps_bin" set currentIssue "${CURRENT_ISSUE:-142}" >/dev/null
"$aps_bin" set workingBranch "${WORKING_BRANCH:-agent/issue-142}" >/dev/null
"$aps_bin" set phase "${WORK_PHASE:-implementing}" >/dev/null
"$aps_bin" set testsPassed "${TESTS_PASSED:-false}" >/dev/null
"$aps_bin" set blocker "${BLOCKER:-}" >/dev/null

"$aps_bin" dump --json
