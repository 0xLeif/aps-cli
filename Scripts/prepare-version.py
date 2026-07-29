#!/usr/bin/env python3
"""Set or verify every intentional aps product-version surface."""

from __future__ import annotations

import argparse
import os
import re
from dataclasses import dataclass
from pathlib import Path


SEMVER = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
ROOT = Path(os.environ.get("APS_VERSION_ROOT", Path(__file__).resolve().parent.parent))


@dataclass(frozen=True)
class Contract:
    path: str
    pattern: str
    expected_count: int = 1


CONTRACTS = (
    Contract("Sources/aps/Aps.swift", r'(version: ")([0-9]+\.[0-9]+\.[0-9]+)(",)'),
    Contract("Sources/aps/Schema.swift", r'(cliVersion = ")([0-9]+\.[0-9]+\.[0-9]+)(")'),
    Contract(
        "Tests/apsTests/APSTests.swift",
        r'(XCTAssertEqual\(document\.cliVersion, ")([0-9]+\.[0-9]+\.[0-9]+)("\))',
    ),
    Contract("Scripts/smoke.sh", r'(CLI_VER" = ")([0-9]+\.[0-9]+\.[0-9]+)(")', 1),
    Contract("Scripts/smoke.sh", r'(--version\)" = ")([0-9]+\.[0-9]+\.[0-9]+)(")', 1),
    Contract(
        "Scripts/smoke.ps1",
        r"(Assert-[Ee]qual ')([0-9]+\.[0-9]+\.[0-9]+)(' \(Invoke-ApsOk --version\))",
        2,
    ),
    Contract("plugin.toml", r'(version = ")([0-9]+\.[0-9]+\.[0-9]+)(")'),
    Contract(
        "specs/aps-cli/requirements.md",
        r'(`(?:--version` string SHALL be|aps --version` prints|cliVersion` equals) `?)([0-9]+\.[0-9]+\.[0-9]+)(`)',
        3,
    ),
    Contract("README.md", r'(Source version: \*\*)([0-9]+\.[0-9]+\.[0-9]+)(\*\*)'),
    Contract("README.md", r'(\n    version: )([0-9]+\.[0-9]+\.[0-9]+)(\n)'),
    Contract("README.md", r'(`fledge-plugin-aps` v)([0-9]+\.[0-9]+\.[0-9]+)( tracks)'),
    Contract("docs/release-readiness.md", r'(Target release line: \*\*)([0-9]+\.[0-9]+\.[0-9]+)(\*\*)'),
    Contract("site/app/page.tsx", r'(const productVersion = ")([0-9]+\.[0-9]+\.[0-9]+)(";)'),
)


def prepare_contract(
    contract: Contract,
    version: str,
    write: bool,
    source: str,
) -> tuple[list[str], str | None]:
    regex = re.compile(contract.pattern)
    matches = list(regex.finditer(source))
    if len(matches) != contract.expected_count:
        return (
            [
                f"{contract.path}: expected {contract.expected_count} version surface(s), "
                f"found {len(matches)}"
            ],
            None,
        )

    mismatches = [match.group(2) for match in matches if match.group(2) != version]
    if not mismatches:
        return [], source if write else None
    if not write:
        return [f"{contract.path}: version surface does not equal {version}"], None

    updated, count = regex.subn(rf"\g<1>{version}\g<3>", source)
    if count != contract.expected_count:
        return [f"{contract.path}: failed to update every version surface"], None
    return [], updated


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--set", dest="set_version")
    mode.add_argument("--check", action="store_true")
    arguments = parser.parse_args()

    version_file = ROOT / "VERSION"
    if arguments.set_version:
        version = arguments.set_version
        if not SEMVER.fullmatch(version):
            raise SystemExit(f"invalid semantic version: {version}")
    else:
        version = version_file.read_text(encoding="utf-8").strip()
        if not SEMVER.fullmatch(version):
            raise SystemExit(f"VERSION is not a stable semantic version: {version}")

    failures: list[str] = []
    updates: dict[Path, str] = {}
    for contract in CONTRACTS:
        path = ROOT / contract.path
        source = updates.get(path)
        if source is None:
            source = path.read_text(encoding="utf-8")
        contract_failures, updated = prepare_contract(
            contract,
            version,
            bool(arguments.set_version),
            source,
        )
        failures.extend(contract_failures)
        if updated is not None:
            updates[path] = updated
    if failures:
        raise SystemExit("\n".join(failures))

    if arguments.set_version:
        for path, source in updates.items():
            path.write_text(source, encoding="utf-8")
        version_file.write_text(f"{version}\n", encoding="utf-8")

    action = "prepared" if arguments.set_version else "verified"
    print(f"{action} aps version {version} across {len(CONTRACTS)} contracts")


if __name__ == "__main__":
    main()
