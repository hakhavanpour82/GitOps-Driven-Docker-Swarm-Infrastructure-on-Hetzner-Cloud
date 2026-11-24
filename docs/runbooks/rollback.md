# Runbook: roll back a release
1. In the GitOps repository: `git revert <deploy-commit> && git push`.
2. Portainer detects the change within about a minute and redeploys the previous image tag.
3. Verify: `docker service inspect applyops_app --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'` on the manager, then check the public URL and Grafana.
