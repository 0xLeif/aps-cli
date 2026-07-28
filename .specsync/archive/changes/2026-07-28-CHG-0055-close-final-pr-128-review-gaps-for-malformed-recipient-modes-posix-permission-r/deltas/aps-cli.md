# aps-cli final PR 128 security review gaps

## ADDED

### REQUIREMENT REQ-aps-cli-032

A missing or null version 2 `recipientMode` SHALL return `decoding_failed`
before KDF work. An unrecognized non-null recipient mode SHALL return
`unsupported_secret_envelope`.

POSIX key-file load and create SHALL revalidate exact `0600` mode through both
descriptor and path immediately before accepting key material. A registered
encrypted watch SHALL pin the canonical state-root target selected by its
initial store for the watch lifetime while continuing descendant validation
beneath that root.

Acceptance Criteria
- Missing and null version 2 modes perform zero KDF work and fail as malformed.
- Unknown non-null recipient modes retain the unsupported-envelope error.
- Post-read POSIX permission widening is rejected with exact bytes preserved.
- Retargeting the configured state-root symlink cannot redirect a running
  registered encrypted watch.
- The full 238-test local lane and every hosted platform gate pass.
