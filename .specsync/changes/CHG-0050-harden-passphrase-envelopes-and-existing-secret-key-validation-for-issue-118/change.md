---
id: CHG-0050-harden-passphrase-envelopes-and-existing-secret-key-validation-for-issue-118
state: accepted
type: migration
base_commit: c365187d9f2baadf097aaedafcb144f60a7a0fa8
---

# Harden passphrase envelopes and existing secret-key validation for issue 118

## Intent

Harden passphrase envelopes and existing secret-key validation for issue 118

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- New passphrase writes use a strict versioned v2 envelope with a fresh random salt and bounded scrypt N=131072,r=8,p=1 parameters; legacy passphrase envelopes migrate transactionally after successful unlock and remain byte-identical on wrong credentials or migration failure; key files are opened and created without symlink races, validated as owned regular files, repaired to owner-only permissions or ACLs when safe, and rejected unchanged otherwise on macOS, Linux, and Windows; unchanged encrypted watch polling does not repeatedly invoke scrypt; production contains no force casts or force tries; security regressions, tri-OS CI, smoke, SpecSync, trust, and provenance gates pass.

## No-spec Rationale

Not applicable
