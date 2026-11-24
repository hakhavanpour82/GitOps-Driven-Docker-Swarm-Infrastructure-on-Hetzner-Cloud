# Runbook: application node failure
1. Alert: InstanceDown for app1 or app2. The site stays up on the other node.
2. Check `docker node ls` and `docker service ps applyops_app` on the manager.
3. If the node is unrecoverable: recreate it with Terraform, run the Ansible baseline, join it to the Swarm and label it `role=app`.
4. Confirm replicas are spread across both nodes again.
