# Spike: SyncState (iCloud) feasibility for `aps`

Issue: [#19](https://github.com/0xLeif/aps-cli/issues/19)

Status: investigation only. No production SyncState code.

## Verdict

**No-go** for shipping or dogfooding `SyncState` in the `aps` CLI during 0.x (and likely beyond while `aps` remains a bare SPM executable).

Local API calls without entitlements do not meaningfully sync. A demo that proves real iCloud round-trips is possible only with a signed, provisioned macOS identity and a non-headless environment; that packaging model conflicts with how `aps` is built, tested, and run today.

## What AppState `SyncState` actually does

Inspected AppState sources under SPM checkout `AppState` (`SyncState.swift`, `Application+SyncState.swift`):

- Backing store is `NSUbiquitousKeyValueStore.default`.
- Values are JSON-encoded `Data` written through a small `UbiquitousKeyValueStoreManaging` adapter.
- A local `StoredState` fallback is used when the iCloud store has no value.
- Apple-platform only (`#if canImport(Security)`); unavailable on Linux.
- AppState docs mirror Apple's requirement: request `com.apple.developer.ubiquity-kvstore-identifier` and configure iCloud Key-Value storage in an Xcode / signed app project.
- The `icloudStore` dependency registers for `didChangeExternallyNotification`. External updates need a process that stays alive long enough to receive them.
- AppState's own `SyncStateTests` exercise encode/decode and the local fallback path; they do not prove cross-device iCloud sync.

Apple documents that writes stay in memory then flush asynchronously; `synchronize()` only hints that data is ready, does not force an upload, and returns `false` when entitlements are missing.

## Bare CLI experiment (local)

A throwaway unsigned Swift executable (no Info.plist, no entitlements) was run on this machine:

```text
synchronize=false
bundleID=nil
synchronize_after_set=false
read_back=nil
```

The existing `swift build` `aps` binary only carries the debug entitlement `com.apple.security.get-task-allow`. It has no ubiquity KVS entitlement and no stable bundle identifier.

Conclusion: from a bare CLI process, `NSUbiquitousKeyValueStore` does not attach to a real iCloud store. Any "it compiled" or "AppState fell back to StoredState" result is not SyncState dogfooding.

## Requirements for a meaningful demo

To demonstrate real SyncState behavior (write on machine A / process 1, observe on machine B / process 2 via iCloud), you would need all of the following:

| Requirement | Why |
| --- | --- |
| Apple Developer Program team | Provision iCloud Key-Value storage on an App ID |
| Stable bundle identifier | KVS identity is `TeamID` + store id (usually bundle id) |
| Entitlement `com.apple.developer.ubiquity-kvstore-identifier` | Without it, `synchronize()` fails and the store is unknown |
| Code signing that embeds that entitlement | SPM `swift build` / `swift run` do not apply restricted entitlements |
| Likely an app-bundle or Xcode-managed target | Restricted entitlements are authorized by provisioning profiles; bare tools are a poor fit |
| Interactive macOS session signed into iCloud | Headless runners typically have no iCloud account |
| Long enough process lifetime | System sync and `didChangeExternally` are async; short CLI exits race the daemon |

Developer ID distribution can work for macOS apps with KVS in some setups (Apple's "App Store only" wording is outdated for some cases), but that still does not make SPM `swift run aps` a viable dogfood path.

## Headless / CI behavior

| Environment | Expectation |
| --- | --- |
| Linux smoke CI | SyncState does not compile into AppState's Apple-only surface; cannot be a cross-platform demo key |
| macOS GitHub Actions | No developer-provisioned iCloud KVS for this open repo, no signed-in iCloud user, no reliable sync |
| Local unsigned `swift test` / `swift run` | At best exercises AppState's local fallback; false confidence |

Automated CI cannot be the proof surface for SyncState. Manual, signed, two-device (or two-Mac) testing would be required.

## Fit with `aps` goals

`GOAL.md` already lists SyncState as out of scope for 0.x. That remains correct:

- `aps` dogfoods AppState as a hermetic CLI with `APS_HOME` / `--state-dir` isolation.
- iCloud KVS is account-global, entitlement-bound, and not path-isolated like FileState.
- Agents and CI need deterministic, local state. SyncState is the opposite: eventual, account-scoped, and environment-dependent.
- Packaging cost (Xcode project, signing secrets, Apple ID) is disproportionate to the demo value for a 0.x harness.

## Go / no-go recommendation

| Option | Recommendation |
| --- | --- |
| Add a SyncState demo key to `aps` in 0.x | **No-go** |
| Rely on local fallback as "dogfooding SyncState" | **No-go** (misleading) |
| Separate signed macOS sample app outside this CLI | Optional later research; not required for `aps` 0.x |
| Keep SyncState out of scope until packaging model changes | **Go** (status quo) |

**Final recommendation: no-go.** Close the spike without production code. Revisit only if `aps` gains a signed macOS app-bundle distribution path and an explicit non-CI dogfood story.
