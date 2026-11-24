#!/usr/bin/env bash
# Managed by Ansible (role mongodb_backup)
# mongodump -> age encryption -> Hetzner Object Storage, then prune and report to Pushgateway.
set -Eeuo pipefail

: "${BACKUP_BUCKET:?BACKUP_BUCKET is not set}"
: "${AGE_RECIPIENT:?AGE_RECIPIENT is not set}"
MONGO_CONTAINER="${MONGO_CONTAINER:-mongodb}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

REMOTE="hz:${BACKUP_BUCKET}/mongo"
OBJ="mongo-$(date -u +%Y%m%dT%H%M%SZ).archive.gz.age"
START="$(date +%s)"
SIZE=0

push_metrics() {
  [ -n "${PUSHGATEWAY_URL:-}" ] || return 0
  local status="$1" now
  now="$(date +%s)"
  {
    echo "mongo_backup_last_run_timestamp_seconds ${now}"
    echo "mongo_backup_last_status ${status}"
    if [ "$status" = "1" ]; then
      echo "mongo_backup_last_success_timestamp_seconds ${now}"
      echo "mongo_backup_last_size_bytes ${SIZE}"
      echo "mongo_backup_last_duration_seconds $((now - START))"
    fi
  } | curl -fsS --max-time 10 --data-binary @- \
        "${PUSHGATEWAY_URL}/metrics/job/mongo_backup/instance/mongodb" \
    || echo "WARN: could not push metrics" >&2
}

fail() {
  local rc="${1:-1}"
  trap - ERR
  echo "Backup FAILED (exit ${rc})" >&2
  rclone deletefile "${REMOTE}/${OBJ}" >/dev/null 2>&1 || true   # never keep a partial object
  push_metrics 0 || true
  exit "$rc"
}
trap 'fail $?' ERR

echo "Dumping to ${REMOTE}/${OBJ}"
docker exec -i "$MONGO_CONTAINER" sh -c \
  'exec mongodump --uri="mongodb://${BACKUP_USER}:${BACKUP_PASSWORD}@127.0.0.1:27017/?authSource=admin&directConnection=true" --archive --gzip --oplog --quiet' \
  | age -r "$AGE_RECIPIENT" \
  | rclone rcat "${REMOTE}/${OBJ}"

SIZE="$(rclone lsf "${REMOTE}" --files-only --format s --include "${OBJ}" | head -n 1)"
SIZE="${SIZE:-0}"
[ "$SIZE" -gt 200 ] || { echo "Backup object missing or too small (${SIZE} bytes)" >&2; fail 1; }

rclone delete "${REMOTE}" --min-age "${RETENTION_DAYS}d" --include "mongo-*.archive.gz.age" \
  || echo "WARN: pruning old backups failed" >&2

push_metrics 1
echo "Backup OK: ${OBJ} (${SIZE} bytes)"
