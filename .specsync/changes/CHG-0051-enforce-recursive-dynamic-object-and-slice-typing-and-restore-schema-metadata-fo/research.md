---
change: CHG-0051-enforce-recursive-dynamic-object-and-slice-typing-and-restore-schema-metadata-fo
artifact: research
---

# Research

Three independent read-only audits traced the complete flow.

- `CLIOutput.typedValue(for:from:)` decodes object values only as
  `ProfileDocument`; a non-profile object becomes `.string(raw)`, and a
  profile-shaped object can silently discard extra fields.
- The lossy conversion affects get, set, dump, watch JSONL, and reset JSON
  because all five paths use `CLIOutput.typedValue`.
- `SchemaJSON` already supports recursive object values, but lacks null,
  floating-point, and array cases and is not reused by machine output.
- `DynamicKeyStorage.fileSetUnlocked` accepts any JSON root for an object;
  State, StoredState, and EncryptedFile paths can bypass object validation
  entirely. Object reads verify only UTF-8.
- `UserSchema.validate` does not validate initial/type agreement, shape field
  names, shape field types, Slice field existence, Slice type agreement, or
  typed Slice initials.
- `KeyCommands.Add` writes `objectShape: [:]` and coerces every Slice initial
  to a string.
- `Schema.UserSchemaMeta` omits the already-promised `keyCount`.

The audits agreed on the affected implementation files and test paths with
greater than 90% confidence. The chosen policy is an open object shape with
required declared fields, explicit Slice field declaration, full recursive JSON
preservation, and schema contract version 6.
