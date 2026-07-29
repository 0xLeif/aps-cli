#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
aps_bin="${APS_BIN:-$repo_root/.build/debug/aps}"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/aps-examples.XXXXXX")"
cleanup() {
    if [[ -n "$fixture_root" && -d "$fixture_root" ]]; then
        rm -rf "$fixture_root"
    fi
}
trap cleanup EXIT

test -x "$aps_bin"
aps_bin="$(cd "$(dirname "$aps_bin")" && pwd)/$(basename "$aps_bin")"

APS_BIN="$aps_bin" \
APS_HOME="$fixture_root/agent" \
CURRENT_ISSUE=321 \
WORKING_BRANCH=agent/example \
TESTS_PASSED=true \
    "$repo_root/examples/agent-memory/run.sh" > "$fixture_root/agent.json"
grep -Fq '"key":"currentIssue"' "$fixture_root/agent.json"
test "$(head -c 1 "$fixture_root/agent.json")" = "{"
if grep -Fq '"key":"secret"' "$fixture_root/agent.json"; then
    echo "Agent checkpoint output contains unrelated secret state" >&2
    exit 1
fi
test "$(APS_HOME="$fixture_root/agent" "$aps_bin" get currentIssue)" = "321"
test "$(APS_HOME="$fixture_root/agent" "$aps_bin" get testsPassed)" = "true"
APS_BIN="$aps_bin" \
APS_HOME="$fixture_root/agent" \
    "$repo_root/examples/agent-memory/run.sh" > "$fixture_root/agent-resume.json"
test "$(APS_HOME="$fixture_root/agent" "$aps_bin" get currentIssue)" = "321"
test "$(APS_HOME="$fixture_root/agent" "$aps_bin" get workingBranch)" = "agent/example"
test "$(APS_HOME="$fixture_root/agent" "$aps_bin" get testsPassed)" = "true"

APS_BIN="$aps_bin" \
APS_HOME="$fixture_root/release" \
RELEASE_VERSION=9.8.7 \
CANDIDATE_COMMIT=0123456789abcdef \
    "$repo_root/examples/release-pipeline/run.sh" > "$fixture_root/release.json"
grep -Fq '"key":"releaseVersion"' "$fixture_root/release.json"
test "$(head -c 1 "$fixture_root/release.json")" = "{"
if grep -Fq '"key":"secret"' "$fixture_root/release.json"; then
    echo "Release checkpoint output contains unrelated secret state" >&2
    exit 1
fi
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get releaseVersion)" = "9.8.7"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get releaseTestsPassed)" = "false"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get riskVerdict)" = "pending"
APS_BIN="$aps_bin" \
APS_HOME="$fixture_root/release" \
RELEASE_PHASE=published \
RELEASE_TESTS_PASSED=true \
RISK_VERDICT=proceed \
    "$repo_root/examples/release-pipeline/run.sh" > "$fixture_root/release-gates.json"
APS_BIN="$aps_bin" \
APS_HOME="$fixture_root/release" \
    "$repo_root/examples/release-pipeline/run.sh" > "$fixture_root/release-resume.json"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get releaseVersion)" = "9.8.7"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get releasePhase)" = "published"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get releaseTestsPassed)" = "true"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get riskVerdict)" = "proceed"
APS_BIN="$aps_bin" \
APS_HOME="$fixture_root/release" \
RELEASE_VERSION=9.8.8 \
CANDIDATE_COMMIT=fedcba9876543210 \
    "$repo_root/examples/release-pipeline/run.sh" > "$fixture_root/release-new-candidate.json"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get releaseVersion)" = "9.8.8"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get releasePhase)" = "planned"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get releaseTestsPassed)" = "false"
test "$(APS_HOME="$fixture_root/release" "$aps_bin" get riskVerdict)" = "pending"

APS_BIN="$aps_bin" \
APS_HOME="$fixture_root/swift" \
    "$repo_root/examples/swift-harness/run.sh" > "$fixture_root/swift.json"
grep -Fq '"name":"swift-harness"' "$fixture_root/swift.json"
if grep -Fq '/usr/bin/env' "$repo_root/examples/swift-harness/StateHarness.swift"; then
    echo "Swift harness contains a Unix-only process launcher" >&2
    exit 1
fi

workflow="$repo_root/examples/github-actions/workflow.yml"
grep -Fq 'version: 1.1.0' "$workflow"
grep -Fq 'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02' "$workflow"
grep -Fq 'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093' "$workflow"
grep -Fq 'APS_HOME: ${{ runner.temp }}/aps-home' "$workflow"
test "$(grep -Fc 'APS_HOME: ${{ runner.temp }}/aps-home' "$workflow")" -eq 2
test "$(grep -Fc 'path: ${{ runner.temp }}/aps-home' "$workflow")" -eq 2
test "$(grep -Fc '7373d124ebb3823c1f7f19651dfffe4d7ed83f51' "$workflow")" -eq 2
if grep -Eq 'uses: actions/[^[:space:]@]+@v[0-9]+' "$workflow"; then
    echo "GitHub Actions example contains a mutable first-party action reference" >&2
    exit 1
fi

for path in \
    examples/README.md \
    examples/agent-memory/README.md \
    examples/github-actions/README.md \
    examples/swift-harness/README.md \
    examples/release-pipeline/README.md \
    docs/use-cases.md
do
    test -f "$repo_root/$path"
done

for example in agent-memory github-actions swift-harness release-pipeline
do
    grep -Fq "examples/$example/" "$repo_root/README.md"
    grep -Fq "../examples/$example/" "$repo_root/docs/use-cases.md"
done
grep -Fq '../examples/' "$repo_root/docs/README.md"
grep -Fq './examples/agent-memory/run.sh' "$repo_root/examples/agent-memory/README.md"
grep -Fq '${APS_BIN:-aps}' "$repo_root/examples/release-pipeline/README.md"
grep -Fq 'StoredState values live in platform UserDefaults' "$repo_root/docs/use-cases.md"
for ignored_root in \
    /.agents/ \
    /.release-state/ \
    /.aps-agent-example/ \
    /.aps-release-example/ \
    /.aps-swift-harness-example/
do
    grep -Fxq "$ignored_root" "$repo_root/.gitignore"
done

echo "example contract checks passed"
