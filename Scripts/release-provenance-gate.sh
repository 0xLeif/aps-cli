#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: $0 [--resolve-only] <tag> [expected-commit]" >&2
    exit 64
}

valid_semver_tag() {
    local candidate="$1"
    local version prerelease build identifier
    local -a identifiers

    [[ "$candidate" == v* ]] || return 1
    version="${candidate#v}"
    [[ "$version" != *+*+* ]] || return 1
    if [[ "$version" == *+* ]]; then
        build="${version#*+}"
        version="${version%%+*}"
        [[ -n "$build" ]] || return 1
        IFS='.' read -r -a identifiers <<< "$build"
        for identifier in "${identifiers[@]}"; do
            [[ "$identifier" =~ ^[0-9A-Za-z-]+$ ]] || return 1
        done
    fi

    if [[ "$version" == *-* ]]; then
        prerelease="${version#*-}"
        version="${version%%-*}"
        [[ -n "$prerelease" ]] || return 1
        IFS='.' read -r -a identifiers <<< "$prerelease"
        for identifier in "${identifiers[@]}"; do
            [[ "$identifier" =~ ^[0-9A-Za-z-]+$ ]] || return 1
            if [[ "$identifier" =~ ^[0-9]+$ ]] && [[ "$identifier" != "0" ]] && [[ "$identifier" == 0* ]]; then
                return 1
            fi
        done
    fi

    [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

resolve_only=false
if [[ "${1:-}" == "--resolve-only" ]]; then
    resolve_only=true
    shift
fi

tag="${1:-}"
expected_commit="${2:-}"
[[ -n "$tag" ]] || usage
valid_semver_tag "$tag" || {
    echo "release provenance: invalid semantic release tag '$tag'" >&2
    exit 64
}

tag_ref="refs/tags/$tag"
if ! git show-ref --verify --quiet "$tag_ref"; then
    echo "release provenance: tag '$tag' is not available locally" >&2
    exit 1
fi

commit="$(git rev-list -n 1 "$tag_ref")"
if [[ -z "$commit" ]] || [[ "$(git cat-file -t "$commit")" != "commit" ]]; then
    echo "release provenance: tag '$tag' does not resolve to a commit" >&2
    exit 1
fi

if [[ -n "$expected_commit" ]]; then
    [[ "$expected_commit" =~ ^([0-9a-fA-F]{40}|[0-9a-fA-F]{64})$ ]] || {
        echo "release provenance: expected commit is not a full object ID" >&2
        exit 64
    }
    expected_commit="$(printf '%s' "$expected_commit" | tr '[:upper:]' '[:lower:]')"
    if [[ "$commit" != "$expected_commit" ]]; then
        echo "release provenance: tag '$tag' moved from $expected_commit to $commit" >&2
        exit 1
    fi
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'tag=%s\ncommit=%s\n' "$tag" "$commit" >> "$GITHUB_OUTPUT"
fi

if [[ "$resolve_only" == true ]]; then
    echo "release provenance: resolved $tag to $commit"
    exit 0
fi

attest_bin="${ATTEST_BIN:-attest}"
policy="${RELEASE_ATTEST_POLICY:-.attest-release.json}"
if ! command -v "$attest_bin" >/dev/null 2>&1; then
    echo "release provenance: attest executable '$attest_bin' is unavailable" >&2
    exit 1
fi
if [[ ! -f "$policy" ]]; then
    echo "release provenance: policy '$policy' is unavailable" >&2
    exit 1
fi

"$attest_bin" verify --commit "$commit" --policy "$policy"
echo "release provenance: verified $tag at $commit"
