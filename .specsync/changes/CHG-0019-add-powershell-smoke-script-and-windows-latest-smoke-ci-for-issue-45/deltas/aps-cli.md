# aps-cli portable Windows smoke

## ADDED

### REQUIREMENT REQ-aps-cli-018

The repository SHALL provide a PowerShell smoke script with the same behavioral coverage as `Scripts/smoke.sh` for FileState / StoredState / keys / stats, and CI SHALL run it on `windows-latest`.

Acceptance Criteria
- `Scripts/smoke.ps1` exercises flag/note/profile persistence, reset, dump, watch, stats, and invalid counter rejection.
- `.github/workflows/windows-smoke.yml` builds the debug binary and runs `Scripts/smoke.ps1` on `windows-latest`.
- `specs/aps-cli/testing.md` and README document both smoke entry points.
