# Runbook: edge (Nginx) recovery
1. Impact: public site, SSH bastion and outbound NAT for private nodes.
2. Rebuild or restore the server, then run `ansible-playbook edge.yml` and `ansible-playbook monitoring_public.yml`.
3. Re-check Cloudflare DNS, that Nginx accepts only Cloudflare ranges, and that private nodes regain outbound access.
