---
change: CHG-0044-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes
artifact: docs
---

# Docs

The canonical `aps-cli` contract records that fresh SecretStore SET uses
`secret.store.lock`, while direct key creation uses `secret.key.lock`.