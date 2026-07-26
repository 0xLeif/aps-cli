---
change: CHG-0046-publish-the-aps-product-site-through-github-pages
artifact: testing
---

# Testing

- `npm ci`
- `npm test`
- `npm run lint`
- `npm audit --omit=dev --audit-level=high`
- `npm run build:pages`
- Assert `site/out/index.html` and `site/out/og.png` exist.
- Assert generated HTML uses `/aps-cli/` asset paths and the canonical Pages
  social-image URL.
- `fledge lanes run verify`
- `specsync change verify CHG-0046-publish-the-aps-product-site-through-github-pages`
- `fledge trust verify`
