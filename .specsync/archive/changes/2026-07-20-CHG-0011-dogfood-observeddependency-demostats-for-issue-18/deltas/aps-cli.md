# aps-cli ObservedDependency DemoStats dogfood

## MODIFIED

### REQUIREMENT REQ-aps-cli-014

`aps stats` SHALL expose the process-local `DemoStats` ObservedDependency, including optional `--watch` with `--count` / `--timeout`.

Acceptance Criteria
- After `aps set counter 3` in the same process, `aps stats` reports last key `counter`.
- `aps stats --json` includes `mutationCount` and `lastMutatedKey`.
- `aps stats --watch --count 1` exits after printing the initial snapshot.
