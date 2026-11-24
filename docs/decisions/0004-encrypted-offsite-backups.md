# 0004: Encrypted off-site backups with monitored freshness
**Decision:** Dump every 6 hours, encrypt with a public key (age), store in object storage in another location, report status through Pushgateway.
**Why:** Snapshots alone are only crash-consistent. Public-key encryption means a compromised server cannot read old backups. A backup that fails silently is worse than none, so staleness is alerted.
**Consequences:** The private key must be stored safely outside the infrastructure and restores must be rehearsed.
