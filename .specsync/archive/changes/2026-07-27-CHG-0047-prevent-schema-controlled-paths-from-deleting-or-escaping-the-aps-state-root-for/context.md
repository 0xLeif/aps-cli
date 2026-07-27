---
change: CHG-0047-prevent-schema-controlled-paths-from-deleting-or-escaping-the-aps-state-root-for
artifact: context
---

# Context

Schema entries control FileState and EncryptedFile paths beneath the active APS
state root. Current validation rejects only empty, absolute, and `..` strings.
It accepts the state root itself (`.`), directories, APS internal files,
colliding paths, and paths traversing symbolic links.

Reset and purge pass those paths to `FileManager.removeItem`, which recursively
removes directories. A schema entry using `.` can therefore delete the entire
state root, including unrelated state and the schema itself.

Issue #111 requires one cross-platform path policy shared by schema validation
and every filesystem adapter. Existing valid nested relative file paths must
continue to work.
