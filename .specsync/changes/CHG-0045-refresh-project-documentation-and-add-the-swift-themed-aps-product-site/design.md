---
change: CHG-0045-refresh-project-documentation-and-add-the-swift-themed-aps-product-site
artifact: design
---

# Design

## Documentation structure

The root README remains the install and usage entry point. `docs/README.md`
becomes the map for deeper material, and `docs/release-readiness.md` owns the
audited release decision. Design records remain historical but carry clear
hardening notes where implementation does not yet enforce every invariant.

## Site direction

The page serves one job: help a Swift developer understand aps, install it, and
trust its engineering posture within one visit.

The palette uses midnight ink, Swift sky blue, compile copper, state mint, and
cloud paper. Avenir Next carries display and body text, with SF Mono for state,
commands, and contract details.

The signature element is a live state tape. It visualizes a typed value moving
through an observable transition, directly expressing the product rather than
adding generic developer-tool decoration.

The page uses semantic HTML, visible keyboard focus, responsive layouts, and a
reduced-motion fallback. It requires no client state or persistent storage.
