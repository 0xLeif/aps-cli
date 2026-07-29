---
change: CHG-0052-enforce-issue-119-release-provenance-on-the-exact-selected-tag-commit-with-passi
artifact: research
---

# Research

Attest 1.0.0 supports `verify --commit <revision> --policy <path>` and strict
JSON policy fields including `requireAttestation`, `requireTestsPassed`,
`requireSignature`, `allowedReviewers`, `trustedKeys`, and `signerPinning`.

`trustedKeys` rejects signed records whose embedded key is untrusted or whose
signature does not validate. `signerPinning` also requires every record claiming
the pinned reviewer identity to be signed by that exact key. Combining those
rules with `allowedReviewers: ["human:leif"]` prevents an unsigned or differently
signed record from spoofing the release identity.

Git tags can move between workflow jobs. Resolving the tag once is not enough if
the publication API later targets the tag name. Rechecking the remote tag
binding in the publication job closes that time-of-check/time-of-use gap.

The Attest composite action at release 1.0.0 installs prebuilt binaries and
checks their SHA-256 sidecars. Its immutable source commit is
`e8a2d928eb4b9a33185c32ba7b8e9b3a985987f2`.
