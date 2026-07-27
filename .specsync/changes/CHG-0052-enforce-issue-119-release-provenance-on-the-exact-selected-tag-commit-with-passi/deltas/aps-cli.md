# aps-cli strict release provenance

## ADDED

### REQUIREMENT REQ-aps-cli-032

Before publishing or backfilling release artifacts, the release workflow SHALL
resolve the selected semantic tag to one exact commit and require that commit
to carry an Attest record with passing tests and a valid Ed25519 signature from
the pinned `human:leif` signer identity. The commit SHALL be reachable from the
default branch, including when it is a merge commit. All test and build
checkouts SHALL use that resolved SHA, and publication SHALL fail if the tag no
longer resolves to it. Manual backfills SHALL use current default-branch gate
and policy files so historical tags need not contain them. The publication job
SHALL require the GitHub `release` Environment. Ordinary pull request workflows
SHALL remain usable without the release key.

Acceptance Criteria
- A missing note, failed-test evidence, unsigned evidence, an invalid signature,
  or a signature from an untrusted key blocks publication.
- Valid signed passing-test evidence from the pinned signer passes.
- Tag pushes and manual backfills use the same gate.
- Manual backfills execute trusted control-plane files from the current default
  branch while gating and building the historical tag commit.
- SemVer-invalid tags are rejected and Attest verifies only the selected commit,
  including for merge commits.
- The selected SHA is used by tests and every platform build.
- Release-critical Actions are pinned by full commit SHA and checkout
  credentials are not persisted.
- The tag binding is checked immediately before and after artifact attachment.
- Repository operations document the required protected `v*` tag ruleset,
  `release` Environment reviewer, external administrator trust, and recovery
  from a failed post-publication check.
