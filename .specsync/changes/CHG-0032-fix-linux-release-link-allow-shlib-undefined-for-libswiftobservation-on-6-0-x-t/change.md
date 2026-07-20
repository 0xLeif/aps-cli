---
id: CHG-0032-fix-linux-release-link-allow-shlib-undefined-for-libswiftobservation-on-6-0-x-t
state: accepted
type: bug_fix
base_commit: 059f44132ee1a840c143a0e62b0ded1b66ad4974
---

# Fix Linux release link: allow-shlib-undefined for libswiftObservation on 6.0.x toolchains (issue 68 backfill failure)

## Intent

Fix Linux release link: allow-shlib-undefined for libswiftObservation on 6.0.x toolchains (issue 68 backfill failure)

## Affected Canonical Specs

- None

## Acceptance Criteria

- Release workflow Linux leg builds aps-linux-x86_64 successfully on the 6.0.x toolchain (link tolerates the libswiftObservation undefined ref); macOS legs unchanged

## No-spec Rationale

CI release workflow fix only; no module API or requirement deltas.
