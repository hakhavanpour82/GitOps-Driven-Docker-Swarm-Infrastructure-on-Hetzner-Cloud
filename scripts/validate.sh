#!/usr/bin/env bash
# Local checks that mirror the CI pipeline.
set -euo pipefail
cd "$(dirname "$0")/.."
yamllint .
( cd ansible && ansible-lint )
( cd ansible && for p in site edge swarm portainer monitoring monitoring_public elk mongodb mongodb_backup runner; do
    ansible-playbook "$p.yml" --syntax-check
  done )
( cd terraform && terraform fmt -check -recursive && terraform init -backend=false -input=false >/dev/null && terraform validate )
echo "All checks passed"
