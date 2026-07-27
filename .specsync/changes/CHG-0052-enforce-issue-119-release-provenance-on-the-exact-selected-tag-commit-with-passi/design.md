---
change: CHG-0052-enforce-issue-119-release-provenance-on-the-exact-selected-tag-commit-with-passi
artifact: design
---

# Design

## Policy split

Keep `.attest.json` and `.trust.toml` unchanged for ordinary branch and pull
request checks. Add `.attest-release.json` for publication. It requires:

- at least one attestation on the selected commit;
- at least one record that reports passing tests;
- at least one cryptographically valid Ed25519 signature;
- only the `human:leif` reviewer identity;
- signatures from the pinned `human:leif` public key.

The public key is not secret. The private key remains outside the repository.

## Exact-commit flow

`Scripts/release-provenance-gate.sh` accepts a semantic release tag and an
optional expected commit. It resolves the tag to a peeled commit, rejects a
binding mismatch, and runs `attest verify --commit` with the release policy.
When `GITHUB_OUTPUT` is present it exports the resolved tag and commit.

The release workflow runs this gate before tests or builds. Every later checkout
uses the exported commit SHA instead of resolving the tag again. The publication
job fetches the tag and re-runs the gate with the expected SHA immediately
before attaching artifacts, then repeats the remote binding check after upload.
A moved or deleted tag therefore makes the workflow fail. The workflow verifies
the exact commit with the `^!` range, which excludes every parent of a merge
commit. It also confirms that the selected commit is reachable from the default
branch.

The workflow defaults to `contents: read`; only the final publication job
receives `contents: write`. Every Action is pinned by full commit SHA and every
checkout disables persisted credentials. The publication job declares the
GitHub `release` Environment. Repository operations must separately configure
its required reviewer and a protected `v*` tag ruleset.

For `workflow_dispatch`, provenance and publication check out the current
default branch as a trusted control plane. This lets an older tag use the
current gate and policy even when the tag predates those files. Tests and builds
still check out only the resolved target SHA.

## Dependency pin

All workflow Actions use immutable commit pins. `CorvidLabs/attest` 1.0.0 is
pinned at `e8a2d928eb4b9a33185c32ba7b8e9b3a985987f2`; it installs the matching
release and validates its published checksum before verification.

## Recovery

Attest notes are backed up by pushing and mirroring `refs/notes/attest`.
Recovery restores that ref, fetches the release tag, and runs the same gate
before a manual backfill. Key compromise stops release activity. Rotation
atomically replaces the trusted and pinned key for `human:leif`. A deliberate
overlap uses a separate transitional reviewer identity because one identity can
pin only one key.
