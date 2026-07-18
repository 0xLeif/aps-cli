# Context -  State Store

StateStore is the non-UI AppState facade used by the CLI. It owns persistence quirks (Linux UserDefaults flush), Observation-based key watching, and Combine-based watching for the `DemoStats` `@ObservedDependency`.
