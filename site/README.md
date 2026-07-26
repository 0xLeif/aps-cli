# aps site

The product and documentation site for [aps](https://github.com/0xLeif/aps-cli).

## Local development

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Validate

```bash
npm run build
npm test
npm run lint
```

The site is built with vinext and deployed through the repository's Sites configuration. Product claims should remain aligned with the root README, `docs/release-readiness.md`, and the SpecSync contracts.

## Design system

- Midnight ink: `#071522`
- Swift sky: `#2F9DFF`
- Compile copper: `#F4773C`
- State mint: `#A9FFD4`
- Cloud paper: `#F3F8FB`
- Display: Avenir Next with system fallbacks
- Utility: SF Mono with cross-platform fallbacks

The signature element is the state tape: a typed value moving through an observable state transition. Keep that motif specific to state changes rather than using it as decoration.
