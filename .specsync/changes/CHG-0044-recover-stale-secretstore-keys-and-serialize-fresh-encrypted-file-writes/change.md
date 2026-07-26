---
id: CHG-0044-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes
state: accepted
type: bug_fix
base_commit: 03bde98e722b064eadf5186e1a325c506fbd4ecb
---

# Recover stale SecretStore keys and serialize fresh encrypted-file writes

## Intent

Recover stale SecretStore keys and serialize fresh encrypted-file writes

## Affected Canonical Specs

- `aps-cli`

## Acceptance Criteria

- Fresh SecretStore.set succeeds after a partial secret.key exists without secret.enc; parallel fresh writes leave one valid decryptable key/envelope; canonical aps-cli and REQ-aps-cli-020 evidence cover the store-lock serialization and recovery behavior; fledge lanes run verify passes.

## No-spec Rationale

Not applicable
