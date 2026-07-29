#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
gate="$repo_root/Scripts/release-provenance-gate.sh"
workflow="$repo_root/.github/workflows/release.yml"
production_policy="$repo_root/.attest-release.json"
trust_workflow="$repo_root/.github/workflows/trust.yml"
attest_bin="${ATTEST_BIN:-attest}"

command -v "$attest_bin" >/dev/null 2>&1 || {
    echo "release provenance contract: attest is required at '$attest_bin'" >&2
    exit 1
}
command -v jq >/dev/null 2>&1 || {
    echo "release provenance contract: jq is required" >&2
    exit 1
}

fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/aps-release-provenance.XXXXXX")"
cleanup() {
    rm -rf "$fixture_root"
}
trap cleanup EXIT

fixture_commit="20869e0eb8a257814eddfa197e520974e50a9629"
trusted_key="gTl3Dqh9F19Wo1Rmw0x+zMuNipG07jeiXfYPW4/Js5Q="

note_prefix='{"commit":"20869e0eb8a257814eddfa197e520974e50a9629",'
note_prefix+='"confidence":1,"humanApproved":true,'
trusted_identity='"publicKey":"gTl3Dqh9F19Wo1Rmw0x+zMuNipG07jeiXfYPW4/Js5Q=",'
trusted_identity+='"reviewer":"human:leif",'
note_suffix='"timestamp":946684800,"verdict":"proceed"}'

valid_note="$note_prefix$trusted_identity"
valid_note+='"signature":"J9RTaVqDuKPeEm9UF6eL+44HN6ejc9hf771I83zp2T9xfF7Zra0m+Jp9OdXp4VUytEJiivnFxTDLoWSr1zbiDg==",'
valid_note+='"testsPassed":true,'
valid_note+="$note_suffix"

failed_tests_note="$note_prefix$trusted_identity"
failed_signature='mSKx2kWnNBZmQmGfJEcvTbZa1dhuN4aAMaYZFw0wzZ1r0yvO'
failed_signature+='KccjfNcL+yviFUH+R86CvqmA9DK17H3fSNB9Ag=='
failed_tests_note+="\"signature\":\"$failed_signature\","
failed_tests_note+='"testsPassed":false,'
failed_tests_note+="$note_suffix"

unsigned_note="$note_prefix"
unsigned_note+='"reviewer":"human:leif","testsPassed":true,'
unsigned_note+="$note_suffix"

invalid_signature_note="$note_prefix$trusted_identity"
invalid_signature='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
invalid_signature+='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='
invalid_signature_note+="\"signature\":\"$invalid_signature\","
invalid_signature_note+='"testsPassed":true,'
invalid_signature_note+="$note_suffix"

untrusted_note="$note_prefix"
untrusted_note+='"publicKey":"7UkoxijRwsbq6QM4kFmVYSlZJzpcY/k2NsFGFKyHN9E=",'
untrusted_note+='"reviewer":"human:leif",'
untrusted_signature='xp7+r3JiSn60nmvRsCLXYjr397ATNZES7n743mTvmL0kpw18'
untrusted_signature+='NkORNw3mbzfcItR59WtH3iGlI2XdpzS5K9HQDQ=='
untrusted_note+="\"signature\":\"$untrusted_signature\","
untrusted_note+='"testsPassed":true,'
untrusted_note+="$note_suffix"

new_repo() {
    local name="$1"
    case_repo="$fixture_root/$name"
    mkdir -p "$case_repo"
    git init -q "$case_repo"
    git -C "$case_repo" config user.name "aps release fixture"
    git -C "$case_repo" config user.email "fixture@example.invalid"
    git -C "$case_repo" config commit.gpgsign false
    printf '%s\n' "release-provenance-fixture" > "$case_repo/fixture.txt"
    git -C "$case_repo" add fixture.txt
    GIT_AUTHOR_DATE="2000-01-01T00:00:00Z" \
        GIT_COMMITTER_DATE="2000-01-01T00:00:00Z" \
        git -C "$case_repo" commit -q -m "fixture: release provenance"
    actual_commit="$(git -C "$case_repo" rev-parse HEAD)"
    if [[ "$actual_commit" != "$fixture_commit" ]]; then
        echo "release provenance contract: fixture commit drifted to $actual_commit" >&2
        exit 1
    fi
    git -C "$case_repo" tag v1.1.0
}

add_note() {
    local record="$1"
    git -C "$case_repo" notes --ref=attest add -m "$record" HEAD
}

expect_gate_failure() {
    local name="$1"
    local expected_rule="$2"
    if (
        cd "$case_repo"
        RELEASE_ATTEST_POLICY="$case_repo/.attest-release.json" "$gate" v1.1.0
    ) >"$fixture_root/$name.output" 2>&1; then
        echo "release provenance contract: $name unexpectedly passed" >&2
        exit 1
    fi
    if ! grep -Fq "$expected_rule" "$fixture_root/$name.output"; then
        echo "release provenance contract: $name did not fail rule $expected_rule" >&2
        cat "$fixture_root/$name.output" >&2
        exit 1
    fi
}

write_policy() {
    cat > "$case_repo/.attest-release.json" <<EOF
{
  "requireAttestation": true,
  "requireTestsPassed": true,
  "requireSignature": true,
  "allowedReviewers": ["human:leif"],
  "trustedKeys": ["$trusted_key"],
  "signerPinning": {"human:leif": "$trusted_key"}
}
EOF
}

new_repo missing-note
write_policy
expect_gate_failure missing-note requireAttestation

new_repo failed-tests
write_policy
add_note "$failed_tests_note"
expect_gate_failure failed-tests requireTestsPassed

new_repo unsigned
write_policy
add_note "$unsigned_note"
expect_gate_failure unsigned requireSignature

new_repo invalid-signature
write_policy
add_note "$invalid_signature_note"
expect_gate_failure invalid-signature trustedKeys

new_repo untrusted-key
write_policy
add_note "$untrusted_note"
expect_gate_failure untrusted-key trustedKeys

new_repo valid
write_policy
add_note "$valid_note"
(
    cd "$case_repo"
    RELEASE_ATTEST_POLICY="$case_repo/.attest-release.json" "$gate" v1.1.0
)

valid_commit="$(git -C "$case_repo" rev-parse HEAD)"
wrong_commit="0000000000000000000000000000000000000000"
if (
    cd "$case_repo"
    RELEASE_ATTEST_POLICY="$case_repo/.attest-release.json" "$gate" v1.1.0 "$wrong_commit"
) >/dev/null 2>&1; then
    echo "release provenance contract: moved tag binding unexpectedly passed" >&2
    exit 1
fi
(
    cd "$case_repo"
    RELEASE_ATTEST_POLICY="$case_repo/.attest-release.json" "$gate" v1.1.0 "$valid_commit"
)

git -C "$case_repo" tag v1.2.3-alpha.1+build.5
(
    cd "$case_repo"
    "$gate" --resolve-only v1.2.3-alpha.1+build.5 "$valid_commit"
)
invalid_tags=(
    v01.2.3
    v1.02.3
    v1.2.03
    v1.2
    v1.2.3-
    v1.2.3-rc.
    v1.2.3-.rc
    v1.2.3-01
    v1.2.3-..
    v1.2.3+
    v1.2.3+build.
    v1.2.3+.build
    v1.2.3+..
)
for invalid_tag in "${invalid_tags[@]}"; do
    invalid_output="$fixture_root/invalid-tag.output"
    set +e
    (
        cd "$case_repo"
        "$gate" --resolve-only "$invalid_tag"
    ) >"$invalid_output" 2>&1
    invalid_status=$?
    set -e
    if [[ "$invalid_status" -ne 64 ]] ||
        ! grep -Fq "release provenance: invalid semantic release tag '$invalid_tag'" "$invalid_output"; then
        echo "release provenance contract: invalid tag $invalid_tag did not fail semantic validation" >&2
        cat "$invalid_output" >&2
        exit 1
    fi
done

merge_repo="$fixture_root/merge-range"
git init -q -b main "$merge_repo"
git -C "$merge_repo" config user.name "aps release fixture"
git -C "$merge_repo" config user.email "fixture@example.invalid"
printf '%s\n' "base" > "$merge_repo/base.txt"
git -C "$merge_repo" add base.txt
git -C "$merge_repo" commit -q -m "fixture: base"
git -C "$merge_repo" switch -q -c side
printf '%s\n' "side" > "$merge_repo/side.txt"
git -C "$merge_repo" add side.txt
git -C "$merge_repo" commit -q -m "fixture: side"
git -C "$merge_repo" switch -q main
printf '%s\n' "main" > "$merge_repo/main.txt"
git -C "$merge_repo" add main.txt
git -C "$merge_repo" commit -q -m "fixture: main"
git -C "$merge_repo" merge -q --no-ff side -m "fixture: merge"
merge_commit="$(git -C "$merge_repo" rev-parse HEAD)"
exact_count="$(git -C "$merge_repo" rev-list "${merge_commit}^!" | wc -l | tr -d ' ')"
first_parent_range_count="$(git -C "$merge_repo" rev-list "${merge_commit}^..${merge_commit}" | wc -l | tr -d ' ')"
if [[ "$exact_count" -ne 1 ]] || [[ "$first_parent_range_count" -le 1 ]]; then
    echo "release provenance contract: merge range fixture did not distinguish ^! from ^.." >&2
    exit 1
fi

production_key="8L3Inb9GXaWv3TM69s1ikAuDcel9F4rtknLZXBkudyI="
jq -e --arg key "$production_key" '
    .requireAttestation == true
    and .requireTestsPassed == true
    and .requireSignature == true
    and .requireHumanApprovalWhenVerdictAtLeast == "block"
    and .allowedReviewers == ["human:leif"]
    and .trustedKeys == [$key]
    and .signerPinning == {"human:leif": $key}
' "$production_policy" >/dev/null

grep -Fq "tags:" "$workflow"
grep -Fq "workflow_dispatch:" "$workflow"
grep -Fq "e8a2d928eb4b9a33185c32ba7b8e9b3a985987f2" "$workflow"
grep -Fq "permissions:" "$workflow"
grep -Fq "  contents: read" "$workflow"
grep -Fq "      contents: write" "$workflow"
control_plane_ref="ref: \${{ github.event_name == 'workflow_dispatch'"
control_plane_count="$(grep -Fc "$control_plane_ref" "$workflow")"
if [[ "$control_plane_count" -ne 2 ]]; then
    echo "release provenance contract: dispatch control-plane checkout is not applied twice" >&2
    exit 1
fi
# shellcheck disable=SC2016
grep -Fq "github.event.repository.default_branch || github.sha" "$workflow"
# shellcheck disable=SC2016
grep -Fq "EVENT_COMMIT: \${{ github.event_name == 'push' && github.sha || '' }}" "$workflow"
grep -Fq 'release-provenance-gate.sh --resolve-only "$RELEASE_TAG" "$EVENT_COMMIT"' "$workflow"
# shellcheck disable=SC2016
grep -Fq "github.event.repository.default_branch || needs.provenance.outputs.commit" "$workflow"
if grep -Eq 'uses: [^[:space:]@]+@(v|main|master)' "$workflow"; then
    echo "release provenance contract: release workflow contains a mutable action reference" >&2
    exit 1
fi
while IFS= read -r action_reference; do
    if [[ ! "$action_reference" =~ @[0-9a-f]{40}([[:space:]]|$) ]]; then
        echo "release provenance contract: action is not pinned by full SHA: $action_reference" >&2
        exit 1
    fi
done < <(grep -E '^[[:space:]]+uses:' "$workflow")
exact_range_count="$(grep -Fc '^!' "$workflow")"
if [[ "$exact_range_count" -ne 2 ]] || grep -Fq '^..' "$workflow"; then
    echo "release provenance contract: Attest must verify the exact commit with ^!" >&2
    exit 1
fi
persist_count="$(grep -Fc 'persist-credentials: false' "$workflow")"
if [[ "$persist_count" -ne 4 ]]; then
    echo "release provenance contract: every checkout must disable persisted credentials" >&2
    exit 1
fi
# shellcheck disable=SC2016
grep -Fq 'ref: ${{ needs.provenance.outputs.commit }}' "$workflow"
grep -Fq 'needs: [provenance, test]' "$workflow"
grep -Fq "environment: release" "$workflow"
grep -Fq "git merge-base --is-ancestor" "$workflow"
grep -Fq "Verify remote tag after publication" "$workflow"
token_env_count="$(grep -Fc 'GITHUB_TOKEN: ${{ github.token }}' "$workflow")"
if [[ "$token_env_count" -ne 4 ]]; then
    echo "release provenance contract: every explicit fetch step must receive the job token" >&2
    exit 1
fi
# shellcheck disable=SC2016
authenticated_fetch_count="$(grep -Fc 'http.https://github.com/.extraheader=AUTHORIZATION: basic ${authorization}' "$workflow")"
if [[ "$authenticated_fetch_count" -ne 6 ]]; then
    echo "release provenance contract: every private-repository fetch must use command-scoped authentication" >&2
    exit 1
fi
# shellcheck disable=SC2016
grep -Fq 'fetch --force origin "refs/tags/${RELEASE_TAG}:refs/tags/${RELEASE_TAG}"' "$workflow"
# shellcheck disable=SC2016
grep -Fq '"$RELEASE_TAG" "$RELEASE_COMMIT"' "$workflow"
grep -Fq "release-provenance-test" "$repo_root/fledge.toml"
grep -Fq "CorvidLabs/attest@e8a2d928eb4b9a33185c32ba7b8e9b3a985987f2" "$trust_workflow"
grep -Fq 'version: "1.0.0"' "$trust_workflow"
# shellcheck disable=SC2016
grep -Fq 'ATTEST_BIN=$ATTEST_BINARY' "$trust_workflow"

echo "release provenance contract checks passed"
