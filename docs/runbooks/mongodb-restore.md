# Runbook: restore MongoDB from backup
1. Fetch the newest object from the backup bucket (`mongo/` prefix) with rclone.
2. Decrypt with the private age key (kept outside the infrastructure) and pipe into `mongorestore --archive --gzip --oplogReplay`.
3. Recreate application users if restoring to a new server (the bootstrap role does this).
4. Point the application at the restored server and verify document counts against expectations.
Record the measured restore duration here after each drill: ______
