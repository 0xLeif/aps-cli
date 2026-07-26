---
change: CHG-0044-recover-stale-secretstore-keys-and-serialize-fresh-encrypted-file-writes
artifact: context
---

# Context

An interrupted first write can leave an invalid `secret.key` without a
`secret.enc` envelope. `FileManager.createFile` does not replace that path,
so the next fresh write must recover the stale key before creating a new one.