# state-store corrupt StoredState and recursive value corrections

## ADDED

### REQUIREMENT REQ-state-store-027

StoredState reads SHALL distinguish an absent defaults object from a present
object that cannot decode as the declared schema type. Absence SHALL use the
schema initial. Present undecodable state SHALL fail as `corrupt_state` without
falling back or mutating the stored object.

Recursive schema values SHALL reject nonfinite doubles in arrays, shaped
fields, and undeclared open-object extensions.

Acceptance Criteria
- Absent StoredState continues to return its initial value.
- Corrupt canonical and legacy StoredState objects return `corrupt_state`.
- Corrupt reads preserve the exact stored object.
- Recursive nonfinite descendants fail validation at every depth.
