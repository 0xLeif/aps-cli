---
id: CHG-0001-adopt-corvidlabs-trust-toolchain-for-the-private-aps-cli
state: implementing
type: migration
base_commit: 4340cdf1ea69e060946f4e418e2b0ea02c7e9144
---

# Adopt CorvidLabs trust toolchain for the private aps CLI

## Intent

Adopt CorvidLabs trust toolchain for the private aps CLI

## Affected Canonical Specs

- None

## Acceptance Criteria

- fledge verify lane builds tests and smokes aps; SpecSync registry lists aps-cli and state-store; Trust config and AGENTS.md markers are committed; CI and Trust workflows run on self-hosted macOS only

## No-spec Rationale

Bootstrap governance, CI, and committed module contracts without applying semantic deltas; aps-cli and state-store specs are authored as canonical companions in the same PR.
