#!/usr/bin/env bash
set -euo pipefail

version="${APS_VERSION:-}"
runner_os="${APS_RUNNER_OS:-}"
runner_arch="${APS_RUNNER_ARCH:-}"
runner_temp="${RUNNER_TEMP:-}"

if [[ -z "$version" || "$version" == "\${{ github.action_ref }}" ]]; then
    echo "::error::The aps Action version is empty. Pin the Action to a release (for example, @v1.0.0) or pass version:" >&2
    exit 1
fi

if [[ "$version" =~ ^v ]]; then
    version="${version#v}"
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::error::Invalid aps release version '$version'; expected a semantic version such as 1.0.0." >&2
    exit 1
fi
if [[ -z "$runner_temp" ]]; then
    echo "::error::RUNNER_TEMP is required so the installer can use a job-scoped location." >&2
    exit 1
fi

case "${runner_os}:${runner_arch}" in
    Linux:X64) asset="aps-linux-x86_64" ;;
    macOS:X64) asset="aps-macos-x86_64" ;;
    macOS:ARM64) asset="aps-macos-aarch64" ;;
    *)
        echo "::error::No aps release binary is published for ${runner_os}/${runner_arch}. Supported runners: Linux/X64, macOS/X64, macOS/ARM64." >&2
        exit 1
        ;;
esac

install_root="$runner_temp/aps"
install_dir="$install_root/bin"
download_dir="$install_root/download"
mkdir -p "$install_dir" "$download_dir"

base_url="https://github.com/0xLeif/aps-cli/releases/download/v${version}"
binary_tmp="$download_dir/${asset}.part"
checksum_file="$download_dir/${asset}.sha256"
binary="$install_dir/aps"

curl --fail --location --retry 5 --retry-all-errors --retry-delay 2 --silent --show-error \
    "${base_url}/${asset}" --output "$binary_tmp"
curl --fail --location --retry 5 --retry-all-errors --retry-delay 2 --silent --show-error \
    "${base_url}/${asset}.sha256" --output "$checksum_file"

checksum="$(awk 'NF { print $1; exit }' "$checksum_file")"
if [[ ! "$checksum" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "::error::Invalid SHA-256 sidecar for ${asset}." >&2
    exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$binary_tmp" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$binary_tmp" | awk '{print $1}')"
else
    echo "::error::Neither sha256sum nor shasum is available to verify ${asset}." >&2
    exit 1
fi
if [[ "$actual" != "$checksum" ]]; then
    echo "::error::SHA-256 mismatch for ${asset} (expected ${checksum}, got ${actual})." >&2
    exit 1
fi

chmod 0755 "$binary_tmp"
mv -f "$binary_tmp" "$binary"
echo "$install_dir" >> "$GITHUB_PATH"

if [[ -z "${APS_HOME:-}" ]]; then
    aps_home="$runner_temp/aps-home"
    mkdir -p "$aps_home"
    echo "APS_HOME=$aps_home" >> "$GITHUB_ENV"
else
    aps_home="$APS_HOME"
fi

{
    echo "version=${version}"
    echo "asset=${asset}"
} >> "$GITHUB_OUTPUT"
echo "Installed aps ${version} (${asset}); APS_HOME=${aps_home}"
