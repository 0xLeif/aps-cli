#!/usr/bin/env python3
"""Render the reviewed aps Homebrew formula template."""

from __future__ import annotations

import re
import sys
from pathlib import Path


SEMVER = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def fail(message: str) -> None:
    raise SystemExit(message)


def main(arguments: list[str]) -> None:
    if len(arguments) != 6:
        fail(
            "usage: render-homebrew-formula.py TEMPLATE OUTPUT VERSION "
            "MACOS_ARM_SHA MACOS_INTEL_SHA LINUX_INTEL_SHA"
        )

    template_path = Path(arguments[0])
    output_path = Path(arguments[1])
    version = arguments[2]
    checksums = arguments[3:]

    if not SEMVER.fullmatch(version):
        fail(f"invalid release version: {version}")
    if any(not SHA256.fullmatch(value) for value in checksums):
        fail("every formula checksum must be 64 lowercase hexadecimal characters")

    replacements = {
        "@VERSION@": version,
        "@MACOS_AARCH64_SHA256@": checksums[0],
        "@MACOS_X86_64_SHA256@": checksums[1],
        "@LINUX_X86_64_SHA256@": checksums[2],
    }
    rendered = template_path.read_text(encoding="utf-8")
    for placeholder, value in replacements.items():
        if rendered.count(placeholder) != 1:
            fail(f"template must contain {placeholder} exactly once")
        rendered = rendered.replace(placeholder, value)

    if re.search(r"@[A-Z0-9_]+@", rendered):
        fail("formula template contains an unresolved placeholder")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")


if __name__ == "__main__":
    main(sys.argv[1:])
