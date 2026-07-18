# Plan

1. Add DemoStats ObservableObject dependency (Combine-gated for Linux).
2. Wire `@ObservedDependency` in StateStore; record mutations on set/reset.
3. Add `aps stats` (+ watch) command, tests, smoke, specs.
