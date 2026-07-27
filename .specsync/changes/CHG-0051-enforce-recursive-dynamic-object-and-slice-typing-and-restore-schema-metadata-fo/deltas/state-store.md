# state-store typed recursive values and Slice invariants

## ADDED

### REQUIREMENT REQ-state-store-026

Dynamic storage SHALL parse and validate registered values against their
declared schema type before mutation and after persistence reads. One recursive
JSON value SHALL represent null, booleans, integers, finite floating-point
numbers, strings, arrays, and objects for schema initials, runtime object
validation, and machine output.

Object shapes SHALL require every declared field with its declared type while
preserving undeclared fields. State, StoredState, FileState, EncryptedFile, and
Slice adapters SHALL reject a non-object root or shape mismatch for an object
entry before mutation. An invalid persisted FileState object SHALL surface as
`corrupt_state`.

Schema validation SHALL run local entry validation before reference validation.
A Slice SHALL have a typed initial and SHALL resolve to an explicitly declared,
type-compatible field on a FileState object parent, including forward
references. Object-valued Slices SHALL validate their nested object shape.
Slice-only metadata SHALL be rejected on other storage kinds.

Acceptance Criteria
- Every dynamic adapter rejects invalid object values before changing state.
- FileState object reads reject malformed, scalar, array-root, missing-field,
  and wrong-field-type data as corrupt state.
- Slice schema tests cover missing and wrong-kind parents, missing fields,
  field/type mismatch, wrong initials, valid forward references, and valid
  String, Int, Bool, and object Slice values.
- Runtime Slice get, set, and reset preserve declared JSON types.
- Registry authority, storage locking, and transactional reset behavior remain
  unchanged.

## MODIFIED

### REQUIREMENT REQ-state-store-022

StateStore reset and purge operations SHALL be transactional for errors
detected before return. Schema purge SHALL acquire the schema lock before the
storage lock, restore the original schema on detected purge failure, and report
rollback failure distinctly. Storage resets SHALL verify their postconditions
before recording success.

Acceptance Criteria
- FileState reset atomically overwrites the initial value under its per-file
  lock without deleting the old file first.
- Secret reset throws, holds `secret.store.lock`, removes and verifies only the
  envelope leaf, and preserves shared `secret.key` material.
- Schema removal plus purge holds `schema.json.lock` through candidate write,
  storage deletion, verification, and any original-schema rollback.
- Registered set and reset operations reload their entry under
  `schema.json.lock` and retain that lock through verified persistence, so a
  stale writer cannot recreate data after successful purge.
- Windows stale-lock recovery never reclaims a valid lock whose owner process
  is alive or cannot be proven dead, regardless of lock age.
- Concurrent APS schema mutation cannot reuse a purged path during the
  transaction.
- Successful rollback rethrows the original operation error; failed rollback
  emits a distinct stable rollback error that truthfully identifies the schema,
  StoredState value, reset FileState file, or staged file that could not be
  restored.
- Bulk reset stops at the first failure, identifies reset, failed, and
  not-attempted keys, and records stats only for successful keys.
- Bulk-reset stats publish only after the outer schema lock is released, on
  both full success and partial-success error paths, so synchronous subscribers
  can safely perform schema operations.
- Parent/Slice compatibility requires an explicitly declared parent object
  field whose type matches the Slice type and whose value and Slice initial
  compare with type-sensitive `SchemaJSON` equality.
- Sibling Slice compatibility derives every field type from the declared parent
  object shape, so identical initial JSON cannot hide incompatible reset types.
- StoredState resets restore canonical and legacy backing objects when
  replacement verification fails.
- StoredState rollback verifies exact raw-object restoration and reports
  `rollback_failed` if restoration cannot be synchronized or verified.
- FileState and Slice reset snapshot the exact prior file bytes under the
  storage lock, restore absent or present state after detected write
  verification failure, and report `rollback_failed` if exact restoration
  cannot be verified.
- Registered StoredState set synchronizes and type-checks the canonical object,
  treating a dropped or mistyped write as persistence failure and restoring
  the exact prior object.
- Destructive leaf removal stages the original regular file and restores it
  when post-delete verification fails. Success requires verified absence of
  both the original and staging leaves. The staging leaf uses a bounded,
  hash-based component independent of the original leaf length.
- Failed staged-leaf restoration reports `rollback_failed` instead of masking
  data stranded under the staging name.
- FileState and Slice storage locks derive from the full portable relative path
  and cannot alias `schema.json.lock` or another same-basename storage path.
- Storage-lock acquisition failures report the affected FileState, Slice, or
  encrypted key rather than misidentifying the failure as `schema.json`.
- Slice reads require the parent object shape to declare the Slice field and
  reject JSON values that do not match that declared field type.
- Slice set and reset use the same declared parent-field type, preserving
  String, Int, Bool, and object values without string coercion.
- Documentation-only edits to a default entry preserve its default adapter
  behavior.
- A default Slice uses its compiled adapter only while its resolved parent also
  behaviorally matches the default parent; replacing the parent selects
  registry storage for the Slice.
- Default flag writes synchronize and verify canonical and legacy values as one
  operation through both typed and string-name entry points, restoring both
  exact prior objects after detected failure.
- Schema removal reloads and compares the candidate before destructive purge,
  then reloads and compares the original after rollback. A dropped schema write
  cannot delete registered storage or hide a failed rollback. Candidate write
  or verification failure restores and verifies the original before returning,
  including when a writer persists and then throws. If that restoration fails,
  the rollback context states that no data purge was attempted; rollback after
  an actual purge failure retains its purge-specific context.
- Failed staged deletion verifies that rollback restored a regular-file
  original and removed the staging leaf before returning the deletion error;
  otherwise it reports `rollback_failed`.
- Default FileState reset adapter synchronization reloads the current disk
  value under the storage lock and cannot delete or replace a newer valid
  write.
- Default adapter synchronization is part of the reset transaction. A
  synchronization failure restores and verifies both the compiled AppState
  adapter cache and the exact pre-reset backing state before returning the
  original error. Bulk reset captures this checkpoint immediately before each
  key so rollback cannot undo an earlier successful key, and stats include only
  those earlier verified successes.
- A failed compiled-adapter restoration reports `rollback_failed` with an
  adapter-specific context that preserves the original synchronization error.
- The default encrypted adapter is a no-op and runs before envelope deletion,
  so an injected adapter failure leaves the exact existing envelope untouched.
