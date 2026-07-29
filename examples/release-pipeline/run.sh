#!/usr/bin/env bash
set -euo pipefail

aps_bin="${APS_BIN:-aps}"
export APS_HOME="${APS_HOME:-$PWD/.aps-release-example}"

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
        echo "Existing key '$name' is incompatible with the release checkpoint" >&2
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
    local keys=(releaseVersion candidateCommit releasePhase releaseTestsPassed riskVerdict)
    local separator=""

    printf '{"checkpoint":['
    for key in "${keys[@]}"; do
        printf '%s' "$separator"
        "$aps_bin" get "$key" --json
        separator=","
    done
    printf ']}\n'
}

ensure_key releaseVersion String release-version.json \
    "Release version under evaluation" --initial ""
ensure_key candidateCommit String candidate-commit.json \
    "Exact release candidate commit" --initial ""
ensure_key releasePhase String release-phase.json \
    "Current release phase" --initial planned
ensure_key releaseTestsPassed Bool release-tests-passed.json \
    "Whether release verification passed" --initial false
ensure_key riskVerdict String risk-verdict.json \
    "Latest deterministic risk verdict" --initial pending

candidate_changed=false
if [[ -n "${RELEASE_VERSION+x}" ]]; then
    if [[ "$("$aps_bin" get releaseVersion)" != "$RELEASE_VERSION" ]]; then
        candidate_changed=true
    fi
fi
if [[ -n "${CANDIDATE_COMMIT+x}" ]]; then
    if [[ "$("$aps_bin" get candidateCommit)" != "$CANDIDATE_COMMIT" ]]; then
        candidate_changed=true
    fi
fi
if [[ "$candidate_changed" == true ]]; then
    "$aps_bin" set releasePhase planned >/dev/null
    "$aps_bin" set releaseTestsPassed false >/dev/null
    "$aps_bin" set riskVerdict pending >/dev/null
fi
if [[ -n "${RELEASE_VERSION+x}" ]]; then
    "$aps_bin" set releaseVersion "$RELEASE_VERSION" >/dev/null
fi
if [[ -n "${CANDIDATE_COMMIT+x}" ]]; then
    "$aps_bin" set candidateCommit "$CANDIDATE_COMMIT" >/dev/null
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

emit_checkpoint
