# aps-cli recursive object and schema contract

## ADDED

### REQUIREMENT REQ-aps-cli-033

APS SHALL preserve registered object values as recursive structural JSON in
every machine-output path. Get, set, dump, watch, and reset SHALL retain all
null, boolean, integer, finite floating-point, string, array, and object values
without a domain-model coercion or JSON string envelope.

`aps key add` SHALL accept repeatable `--field NAME=TYPE` declarations for
object shapes. It SHALL reject malformed, duplicate, unsupported, or
non-object field declarations before mutating `schema.json`. Object initials
SHALL match their declared type and every declared shape field. Undeclared
object fields MAY be retained.

Slice entries SHALL name a declared field on an existing FileState object
parent. The parent field type, Slice type, and typed Slice initial SHALL agree.
Invalid or formerly unshaped Slice definitions SHALL fail as `schema_invalid`
before storage mutation.

`aps schema` SHALL publish `schemaVersion` 6 and
`userSchema.keyCount`. `keyCount` SHALL equal both the active registry key
count and the number of projected key contracts.

Acceptance Criteria
- Arbitrary nested objects with profile-like and extra fields round-trip through
  all machine outputs without field loss or stringification.
- Recursive JSON tests cover null, Bool, Int, finite Double, String, arrays,
  and nested objects.
- `key add --field name=String --field retries=Int` persists a usable shape;
  malformed and duplicate declarations fail without changing the registry.
- Schema loading rejects initial/type/shape mismatches and invalid Slice
  parent, field, type, or initial combinations.
- The default seven-key schema and profile/profileName behavior remain
  compatible.
- `aps schema` reports version 6 and a `keyCount` equal to `keys.count`.

## MODIFIED

### REQUIREMENT REQ-aps-cli-019

`aps schema` SHALL emit one cacheable JSON document describing the CLI
contract: cliVersion, integer schemaVersion (bumped when the document shape
changes), state-root precedence, live registered keys, `userSchema` meta
(formatVersion, keyCount, hash), commands, payload shapes, and the error table.

Acceptance Criteria
- Output is valid JSON with top-level integer `schemaVersion` equal to 6 after
  this change.
- Keys cover every entry in the active `schema.json`; commands cover every
  subcommand including `key`.
- `cliVersion` equals `aps --version`.
- `userSchema.hash` changes when the registry changes.
- `userSchema.keyCount` equals both the active registry key count and the
  number of projected key contracts.
- Live values stay in `dump`.

### REQUIREMENT REQ-aps-cli-024

`aps schema` SHALL advertise root-or-subcommand `--state-dir`, reset
`--registered`, repeatable key-add `--field NAME=TYPE`, bulk reset report
payloads, and integer `schemaVersion` 6 for this contract shape.

Acceptance Criteria
- `aps schema` emits `"schemaVersion":6`.
- The `reset` command entry lists flags including `--registered`.
- The `key add` command entry lists flags including `--field`.
