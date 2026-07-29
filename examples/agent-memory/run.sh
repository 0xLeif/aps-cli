#!/usr/bin/env bash
set -euo pipefail

aps_bin="${APS_BIN:-aps}"
export APS_HOME="${APS_HOME:-$PWD/.aps-agent-example}"

ensure_key() {
    local name="$1"
    local type="$2"
    local path="$3"
    local doc="$4"
    shift 4
    local inventory
    local metadata

    inventory="$("$aps_bin" keys --quiet)"
    if ! printf '%s\n' "$inventory" | grep -Fx "$name" >/dev/null; then
        "$aps_bin" key add "$name" \
            --type "$type" --storage FileState --path "$path" --doc "$doc" \
            "$@" >/dev/null
    fi

    metadata="$("$aps_bin" key list --json)"
    if ! printf '%s\n' "$metadata" |
        grep -F "\"detail\":\"$doc\",\"key\":\"$name\",\"storage\":\"FileState\",\"type\":\"$type\"" >/dev/null
    then
        echo "Existing key '$name' is incompatible with the agent-memory checkpoint" >&2
        return 65
    fi
    if ! awk -v key="$name" -v expected_path="$path" '
        index($0, "\"name\" : \"" key "\"") { in_entry = 1; found = 1 }
        in_entry && index($0, "\"path\" : \"" expected_path "\"") { path_matches = 1 }
        in_entry && /^    }/ { exit(path_matches ? 0 : 1) }
        END { if (!found || !path_matches) exit 1 }
    ' "$APS_HOME/schema.json"
    then
        echo "Existing key '$name' uses an incompatible backing path" >&2
        return 65
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

ensure_key currentIssue Int current-issue.json \
    "Issue currently owned by this agent" --initial 0
ensure_key workingBranch String working-branch.json \
    "Branch currently owned by this agent" --initial ""
ensure_key phase String phase.json \
    "Current workflow phase" --initial idle
ensure_key testsPassed Bool tests-passed.json \
    "Whether the latest verification passed" --initial false
ensure_key blocker String blocker.json \
    "Current blocker, or an empty string" --initial ""

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
