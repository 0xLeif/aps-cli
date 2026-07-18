# Spike: ModelState (SwiftData) feasibility for `aps`

Issue: [#20](https://github.com/0xLeif/aps-cli/issues/20)

Status: investigation only. No production ModelState code.

## Verdict

**No-go** for shipping or dogfooding `ModelState` / SwiftData in the `aps` CLI during 0.x.

`ModelContainer` open cost is measurable but not catastrophic on its own. The blocker is fit: SwiftData is Apple-only (Linux CI cannot exercise it), schema migration is owned outside AppState, and short-lived CLI processes pay store setup on every invocation for little dogfood value over existing `FileState`.

## What AppState `ModelState` actually does

Inspected AppState 3.0.1 under SPM checkout (sources + `documentation/en/usage-modelstate.md` + `specs/swiftdata/swiftdata.spec.md`):

- Entire surface is gated on `#if canImport(SwiftData)` (iOS 17+ / macOS 14+ / tvOS 17+ / watchOS 10+ / visionOS 1+). Compiled out on Linux and Windows.
- You register a shared `ModelContainer` as a normal AppState `Dependency` via `modelContainer(_:)`. The autoclosure runs once on first access within a process.
- `Application.ModelState<Model>` reads via live `ModelContext.fetch`; mutates via `insert` / `delete` / `save` / `deleteAll` on `mainContext`.
- Not value-backed: nothing is stored in AppState's cache. SwiftData is the source of truth.
- All access is `@MainActor`.
- Lenient mutators log and swallow SwiftData errors; `strict` exposes throwing variants.
- Mutations are not broadcast to SwiftUI; AppState intends `ModelState` for view models / services, with `@Query` for reactive views.
- AppState tests use `ModelConfiguration(isStoredInMemoryOnly: true)`. They prove DI and CRUD wiring, not on-disk CLI persistence, migration, or multi-process use.

AppState does not wrap schema versioning, lightweight/custom migration, or store URL selection beyond whatever you pass into `ModelContainer` / `ModelConfiguration`.

## ModelContainer cost for short-lived CLI processes

A throwaway local macOS executable (not committed) timed SwiftData vs JSON under `/tmp`:

| Operation | Median (approx.) |
| --- | --- |
| `ModelContainer` cold create (new on-disk store) | 6-14 ms |
| `ModelContainer` reopen existing store | 2-3 ms |
| open + insert + save + fetch | 15-16 ms |
| JSON encode + atomic write + read | ~1 ms |
| in-memory `ModelContainer` create | ~1 ms |

Baseline `aps` on the same machine (debug build, already linked):

| Command | Wall time (approx.) |
| --- | --- |
| `aps --help` | ~12 ms |
| `aps get note` / `get profile` | ~17-19 ms |

Interpretation:

- Store open is a few milliseconds to low tens of milliseconds per process. Not "seconds of SwiftData tax."
- A full open/CRUD path is roughly an order of magnitude slower than the FileState-style JSON path for the same tiny payload.
- Every `aps` invocation is a new process, so AppState's "evaluate the container autoclosure once" only helps within that process. There is no warm container across CLI calls unless `aps` becomes long-lived (daemon / REPL), which is out of scope for 0.x.
- Process/dyld startup already dominates tiny commands; ModelState adds a persistent tax on every keyed command that touches the store, and it is the wrong shape for agent-style many-short-invocations workloads.

**Answer to "does per-process startup make this pointless?"** For a dogfood CLI that already has `FileState`, yes: the incremental demo value does not justify the platform split, migration story, and MainActor store lifecycle. The absolute milliseconds alone would not be a hard veto if everything else fit.

## Migration story

SwiftData owns migration (`VersionedSchema`, `SchemaMigrationPlan`, lightweight vs custom). AppState only injects whatever `ModelContainer` you build.

For an `aps` demo under the state root that would mean:

| Concern | Implication |
| --- | --- |
| Schema evolution | Any `@Model` change risks failing container open until you ship a migration plan |
| Store location | Custom `ModelConfiguration(url:)` under `APS_HOME` / `--state-dir` is feasible, but reset semantics differ from FileState (delete store files vs rewrite JSON) |
| Failure mode | Container creation failures are typically fatal at first access; AppState examples use `fatalError` |
| Multi-process | Concurrent CLI processes against one store are a concurrency hazard; FileState atomic JSON is a simpler cross-process story for `watch` |
| Test isolation | In-memory containers work for unit tests; hermetic on-disk isolation under temp `--state-dir` needs careful store URL wiring and cleanup |

Compared with today's `profile` / `note` FileState keys (Codable JSON files, trivial reset, Linux-safe), ModelState is a heavier persistence product than the CLI needs.

## Linux CI and agent surface

`GOAL.md` and Linux smoke CI treat cross-platform build/test/smoke as part of the agent-ready bar.

| Environment | Expectation |
| --- | --- |
| Linux smoke CI | SwiftData / `ModelState` unavailable; cannot be a core demo key exercised by `./Scripts/smoke.sh` |
| macOS CI / local | Could compile a `#if canImport(SwiftData)` optional path, but agents and Linux would never see it |
| AppState itself | Library builds on Linux with ModelState compiled out; that does not help `aps` dogfood the feature |

A macOS-only ModelState key would be a second-class demo: invisible to the Linux smoke gate that the 0.2.0 milestone already relies on.

## Fit with `aps` goals

`GOAL.md` already lists ModelState as out of scope for 0.x. That remains correct:

- `aps` dogfoods AppState as a hermetic CLI with path-isolated FileState / StoredState.
- ModelState targets long-lived Apple apps (shared container + `@Query` / view models), not short CLI processes.
- Agents need deterministic, local, cross-platform state. SwiftData is platform-bound and store-lifecycle heavy.
- Existing structured persistence (`profile` FileState) already covers Codable-on-disk dogfooding without SwiftData.

## Go / no-go recommendation

| Option | Recommendation |
| --- | --- |
| Add a ModelState-backed demo key to `aps` in 0.x | **No-go** |
| Optional `#if canImport(SwiftData)` macOS-only key | **No-go** for 0.x (splits dogfood / CI; migration and watch story still weak) |
| Separate long-lived macOS sample (app or daemon) outside this CLI | Optional later research; not required for `aps` 0.x |
| Keep ModelState out of scope until packaging or process model changes | **Go** (status quo) |

**Final recommendation: no-go.** Close the spike without production code. Revisit only if `aps` gains a long-lived process model or an explicit macOS-only sample that is not part of the core Linux-agent CLI contract.
