# Testing -  State Store

- Round-trip tests for each DemoKey seed and registry string-key helpers
- reset and resetAll restore initials
- watchBlocking in-process and FileState change detection
- dump includes dependency-driven timestamp and all keys
- DemoStats ObservedDependency records mutations and Combine publishes on change
- watchStatsBlocking detects dependency mutation

- Encrypted-file `secret` round-trip / wrong-passphrase `secretUnlockFailed` / corrupt envelope `decodingFailed`.
- Secret SET unlock-before-rewrite; parallel schema RMW under SchemaFileLock.
- `resetAll` leaves user keys; `resetAllRegistered` clears them.
- Slice `profileName` writes land in parent `profile` FileState.
- `read*FromDiskIfPresent` returns nil when absent and throws `corruptState` when torn.
- `watchBlocking` throws `corruptState` when a FileState file becomes undecodable.
