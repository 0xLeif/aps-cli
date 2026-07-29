---
change: CHG-0064-fix-release-workflow-fetch-authentication-so-signed-tags-and-attest-notes-can-be
artifact: context
---

# Context

The v1.1.0 tag push failed twice before provenance verification because the
release workflow constructed a manual HTTP Authorization header. Git reported
`Failed sending HTTP request` while fetching the tag. The checkout action can
manage the job-scoped credential itself, avoiding custom header construction
while retaining least-lived GitHub token authentication.
