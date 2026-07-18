# aps-cli Windows swift test

## MODIFIED

### REQUIREMENT REQ-aps-cli-018

The repository SHALL provide a PowerShell smoke script with the same behavioral coverage as `Scripts/smoke.sh` for FileState / StoredState / keys / stats, and CI SHALL run `swift test` plus that smoke script on `windows-latest`.

Acceptance Criteria
- `Scripts/smoke.ps1` exercises flag/note/profile persistence, reset, dump, watch, stats, and invalid counter rejection.
- `.github/workflows/windows-smoke.yml` runs `swift test` then `Scripts/smoke.ps1` on `windows-latest` (Swift 6.3.1+).
- `APS_HOME` resolution tests mutate the process environment with a portable helper (not POSIX-only `setenv`).
- `specs/aps-cli/testing.md` and README document the Windows test + smoke path.
