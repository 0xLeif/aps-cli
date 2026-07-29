# aps-cli final numeric validation correction

## MODIFIED

### REQUIREMENT REQ-aps-cli-035

Dynamic Bool parsing SHALL accept the same tokens as the central Bool parser,
including `y` and `n`. Object Slice schemas SHALL require a parent initial that
satisfies every nested Slice shape and identical shapes for sibling object
Slices targeting one parent field. Direct parent writes SHALL satisfy every
targeting Slice constraint before mutation. Canonical terminology SHALL list
every public recursive SchemaJSON case. Recursive JSON decoding SHALL reject
integral numeric values that cannot be represented exactly as native Int values.

Acceptance Criteria
- Dynamic Bool values accept `y`, `Y`, `n`, and `N`.
- Invalid parent initials and incompatible sibling Slice shapes are rejected.
- Invalid direct parent writes fail without creating or changing storage.
- Canonical terminology includes array and object cases.
- Out-of-range integral JSON is rejected instead of rounded through Double.
- Focused regressions and the full quality lane pass.
