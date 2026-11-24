# Architecture

## Scope
A single-location platform (eight servers) with one public entry point, a two-node application tier, one database, and supporting CI, monitoring and logging servers. High availability across locations is a planned second phase.

## Network and addressing
- Hetzner private network `192.168.0.0/16`; active subnet `192.168.100.0/24`. `192.168.200.0/24` is reserved for a second location.
- Fixed allocations: Nginx .10, app1 .21, app2 .22, Portainer .30, runner .31, monitoring .40, ELK .50, MongoDB .60.
- Docker address pools are set to `10.20.0.0/16` (overlay) and `172.30.0.0/16` (bridge) so they never overlap the host network.
- Only the Nginx edge has a public IPv4 address. It also provides SSH jump access and outbound NAT for the private nodes.

## Firewall matrix (inbound)
| Server | Allowed |
|---|---|
| nginx | 80/443 from Cloudflare ranges; SSH from admin addresses; exporters from monitoring |
| app1, app2 | 8080 from nginx; 2377, 7946, 4789 between Swarm nodes; 9001 from portainer; exporters from monitoring |
| portainer | HTTPS UI from admin addresses; SSH via bastion |
| runner | SSH via bastion only |
| monitoring | 3000, 9090, 9093 from nginx; 9091 from mongodb |
| elk | 9200 from nginx and app nodes (log shipping); 5601 from nginx if published |
| mongodb | 27017 from app1 and app2; 9216 from monitoring |

## Main flows
1. **Request:** user, Cloudflare, Nginx (round robin), app node (Swarm ingress), MongoDB.
2. **Deploy:** push to the app repo, build and push image `:commit-hash`, commit tag to the GitOps repo, Portainer polls and updates the stack (one replica at a time, `start-first`, rollback on failure).
3. **Logs:** Filebeat on the app nodes and the edge sends to Elasticsearch (`applyops-*`, 14-day lifecycle).
4. **Metrics and alerts:** Prometheus scrapes exporters, evaluates rules and sends to Alertmanager, which emails the team. The backup job reports status through Pushgateway.
5. **Backup:** systemd timer on the database server, dump, encrypt, upload, prune, report.

## Failure modes
| Failure | Impact | Mitigation and recovery |
|---|---|---|
| App node down | Capacity halves; service continues | Nginx and Swarm route to the other replica; replace the node with Terraform and Ansible |
| Nginx edge down | Site, bastion and NAT unavailable | Rebuild from code or snapshot; separating roles and adding a second edge is on the roadmap |
| Portainer (manager) down | Running services continue; no deployments | Restore the node; back up Swarm state |
| MongoDB down | Application errors | Restore from the latest encrypted backup; RPO of at most 6 hours |
| Monitoring down | No dashboards or alerts | UptimeRobot still alerts from outside |
| ELK down | No log search; shippers retry | Rebuild; logs are re-shipped from the nodes as they are available |
| Backup job fails | Growing recovery gap | `MongoBackupFailed` and `MongoBackupStale` alerts |

## Known limitations
- Single location, single database node, single edge server (by design for this phase).
- MongoDB and Elasticsearch use plain connections inside the private network; TLS is planned.
