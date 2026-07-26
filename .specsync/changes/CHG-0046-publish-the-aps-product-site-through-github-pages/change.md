---
id: CHG-0046-publish-the-aps-product-site-through-github-pages
state: accepted
type: operations
base_commit: 5e9c35d2721e26d8ce913fe2893230e95b2a9e2b
---

# Publish the aps product site through GitHub Pages

## Intent

Publish the aps product site through GitHub Pages

## Affected Canonical Specs

- None

## Acceptance Criteria

- The site exports static files under site/out with the /aps-cli base path; pull requests validate the vinext build, static Pages build, rendered output, lint, and production dependency audit; pushes to main upload and deploy the Pages artifact; the existing Sites build remains valid.

## No-spec Rationale

This change adds static export and delivery automation for the existing documentation site without changing aps CLI or state-store behavior.
