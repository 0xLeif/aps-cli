# aps documentation

aps is a Swift CLI for exploring AppState outside SwiftUI and exposing typed state to terminal users, agents, and CI.

## Start here

| Goal | Read |
| --- | --- |
| Install and use the CLI | [Project README](../README.md) |
| Understand user-defined keys | [Dynamic schema design](design/dynamic-schema.md) |
| Decide whether the next tag is ready | [Release readiness](release-readiness.md) |
| Operate signed releases and recover provenance | [Release provenance](release-provenance.md) |
| Understand platform coverage | [Windows and tri-OS readiness](windows-readiness.md) |
| Review non-goals | [SyncState spike](spikes/syncstate-feasibility.md) and [ModelState spike](spikes/modelstate-feasibility.md) |
| Inspect normative behavior | [`specs/aps-cli`](../specs/aps-cli/) and [`specs/state-store`](../specs/state-store/) |

## Mental model

```text
schema.json
    |
    +-- State ----------- process-local value
    +-- StoredState ----- UserDefaults-backed value
    +-- FileState ------- JSON file
    +-- EncryptedFile --- encrypted envelope
    +-- Slice ----------- typed field projection
    |
    +-- human output / JSON / JSONL
```

The user schema is mutable data. The compiled CLI contract is versioned separately. `aps schema --json` joins both views so an agent can discover commands, error codes, output shapes, and the current key inventory in one request.

## Working on aps

Use the repository-native verification surface:

```bash
fledge lanes run verify
fledge trust verify
```

Code and specs change together. Follow [`AGENTS.md`](../AGENTS.md) for Swift conventions, SpecSync workflow, ticket claiming, and release requirements.

## Documentation principles

- State current behavior, including limitations.
- Keep machine-contract examples byte-accurate.
- Separate shipped behavior from proposed hardening.
- Link design decisions to normative SpecSync requirements.
- Distinguish soft pull request provenance from the strict release publication gate.
- Do not describe partial platform distribution as stronger than it is.
