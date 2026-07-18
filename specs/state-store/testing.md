# Testing -  State Store

- Round-trip tests for each DemoKey
- reset and resetAll restore initials
- watchBlocking in-process and FileState change detection
- dump includes dependency-driven timestamp and all keys
- DemoStats ObservedDependency records mutations and Combine publishes on change
- watchStatsBlocking detects dependency mutation

- SecureState `secret` round-trip / Keychain delete (Darwin) or keychainUnavailable (else).

- Slice `profileName` writes land in parent `profile` FileState.
- `read*FromDiskIfPresent` returns nil when absent and throws `corruptState` when torn.
- `watchBlocking` throws `corruptState` when a FileState file becomes undecodable.
