# aps-cli recursive JSON review corrections

## ADDED

### REQUIREMENT REQ-aps-cli-034

APS machine output SHALL preserve recursive JSON structure and numeric value.
Equivalent integral JSON spellings such as `1`, `1.0`, and `1e0` MAY
canonicalize to an integer because JSON and Foundation Codable do not expose a
stable lexical numeric subtype.

Schema validation SHALL reject nonfinite doubles at every recursive array or
object depth, including undeclared fields preserved by an open object shape.
Schema version 6 SHALL advertise null, boolean, integer, finite number, string,
array, and object for every recursive value-bearing payload.

Acceptance Criteria
- Integral numeric spellings have documented canonical semantics while
  nonintegral finite values retain their numeric value.
- Nested infinity and NaN values fail schema validation.
- KeyValuePayload, WatchEvent, and ResetPayload advertise the complete
  recursive JSON kind set.
- Focused regressions and the full quality lane pass.
