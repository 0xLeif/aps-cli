# Design

`DemoStats` is process-local. Apple uses `@ObservedDependency`; Linux/Windows fall back to `@AppDependency` because ObservedDependency needs Combine/ObservableObject.
