# 0001: Docker Swarm instead of Kubernetes
**Decision:** Use Docker Swarm with Portainer.
**Why:** Two application nodes and a small team do not justify the operational cost of a Kubernetes control plane. Swarm gives rolling updates, secrets, overlay networking and rollback with far less to run.
**Consequences:** Fewer ecosystem tools; the stack files remain portable Compose syntax, which eases a later migration.
