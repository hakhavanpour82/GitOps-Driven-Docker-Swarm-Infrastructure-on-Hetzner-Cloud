# 0002: GitOps with Portainer polling
**Decision:** The pipeline writes the new image tag into a GitOps repository; Portainer polls it every minute.
**Why:** Git becomes the single source of truth and rollback is a `git revert`. Portainer has no public address, so webhooks cannot reach it; polling needs no inbound access.
**Consequences:** Up to one minute of deployment latency; deploy credentials are limited to one repository.
