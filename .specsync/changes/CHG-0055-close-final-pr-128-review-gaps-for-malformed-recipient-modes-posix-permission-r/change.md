---
id: CHG-0055-close-final-pr-128-review-gaps-for-malformed-recipient-modes-posix-permission-r
state: accepted
type: bug_fix
base_commit: b10728b81c4b718c239cd1119ded36b82ee60f17
---

# Close final PR 128 review gaps for malformed recipient modes, POSIX permission races, and pinned encrypted watch roots

## Intent

Close final PR 128 review gaps for malformed recipient modes, POSIX permission races, and pinned encrypted watch roots

## Affected Canonical Specs

- `aps-cli`
- `state-store`

## Acceptance Criteria

- Missing or null v2 recipientMode returns decoding_failed before KDF work; unknown non-null modes remain unsupported_secret_envelope; POSIX key loads reject post-read permission widening; registered encrypted watch stays on its initial canonical root after configured symlink retargeting; 238 serial and parallel tests plus all hosted gates pass

## No-spec Rationale

Not applicable
