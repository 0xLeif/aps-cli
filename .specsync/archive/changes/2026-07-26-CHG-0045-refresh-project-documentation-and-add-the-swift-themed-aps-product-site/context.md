---
change: CHG-0045-refresh-project-documentation-and-add-the-swift-themed-aps-product-site
artifact: context
---

# Context

The public README had grown into a complete technical reference but no longer
gave a new Swift developer a fast product-level introduction. Several sections
also described pre-1.0 platform and concurrency states that no longer matched
current main.

A release-readiness audit of commit `5a05e38` found strong verification and
SpecSync coverage alongside concrete safety and distribution blockers. Those
findings need a durable, honest documentation home before the next release.

The repository also lacked a focused product site. The requested site should
share CorvidLabs' precise engineering character while using a more personal,
Swift-specific visual identity.
